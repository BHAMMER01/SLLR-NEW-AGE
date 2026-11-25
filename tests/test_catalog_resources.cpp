#include "save_io_fixture.hpp"
#include "slrr/gameref.hpp"
#include <cstring>
#include <set>

using namespace slrr;

namespace {
struct Entry {
  uint32_t parent, id;
  std::string payload;
};

void write_pack(const fs::path& path, const std::vector<std::string>& dependencies,
                const std::vector<Entry>& entries) {
  const size_t table = 16 + dependencies.size() * 64;
  const size_t first = table + 16;
  size_t payload = first + entries.size() * 23;
  size_t size = payload;
  for (const auto& entry : entries) size += entry.payload.size();
  std::vector<uint8_t> bytes(size);
  auto put = [&](size_t at, uint32_t value) {
    for (int i = 0; i < 4; ++i) bytes[at + i] = uint8_t(value >> (8 * i));
  };
  std::memcpy(bytes.data(), "RPAK", 4);
  put(4, 0x200);
  put(8, static_cast<uint32_t>(dependencies.size()));
  for (size_t i = 0; i < dependencies.size(); ++i) {
    SLRR_REQUIRE(dependencies[i].size() < 56);
    put(16 + i * 64, static_cast<uint32_t>((i + 1) << 16));
    std::memcpy(bytes.data() + 20 + i * 64, dependencies[i].data(), dependencies[i].size());
  }
  put(table, static_cast<uint32_t>(entries.size() * 23));
  put(table + 4, static_cast<uint32_t>(entries.size()));
  for (size_t i = 0; i < entries.size(); ++i) {
    const auto& entry = entries[i];
    const size_t at = first + i * 23;
    put(at, entry.parent);
    put(at + 4, entry.id);
    bytes[at + 8] = 8;
    put(at + 14, static_cast<uint32_t>(payload));
    put(at + 18, static_cast<uint32_t>(entry.payload.size()));
    std::memcpy(bytes.data() + payload, entry.payload.data(), entry.payload.size());
    payload += entry.payload.size();
  }
  fs::create_directories(path.parent_path());
  std::ofstream out(path, std::ios::binary);
  out.write(reinterpret_cast<const char*>(bytes.data()), bytes.size());
  SLRR_REQUIRE(bool(out));
}

void scripted_parts_survive_other_car_filter() {
  Fixture f;
  write_pack(f.root / "parts.rpk", {}, {
    {0, 0xf243, ""}, {0, 0xf242, ""}, {0, 0xf246, ""},
    {0xf243, 0x10, "script common_wheel.class\n"},
    {0xf242, 0x11, "script common_body.class\n"}});
  write_pack(f.root / "cars.rpk", {}, {{0, 0x1000, ""}});
  for (const char* name : {"first", "second"})
    write_pack(f.root / "cars" / (std::string(name) + ".rpk"),
               {"cars.rpk", "parts.rpk"}, {
      {0x00011000, 0x100, ""},
      {0x0002f243, 1, "script steering_wheel.class\n"},
      {0x0002f242, 2, ""},
      {2, 3, "script body_panel.class\n"},
      {0x0002f246, 4, "script seat.class\n"}});
  const int parts = f.packs.open_lib("parts.rpk");
  f.packs.open_lib("cars.rpk");
  const int first = f.packs.open_lib("cars/first.rpk");
  const int second = f.packs.open_lib("cars/second.rpk");
  register_resref_natives(f.vm, f.packs, f.sections);
  Object player, car;
  player.class_name = "java.game.Player";
  car.class_name = "java.game.Vehicle";
  gameref_upsert(&car);
  f.vm.set_static("java.game.GameLogic", "player", Value::make_obj(&player));
  const auto id = [](int pack, uint32_t local) { return RpkIndex::make_full_id(pack, local); };
  auto select_car = [&](int pack) {
    player.fields["car"] = Value::make_obj(pack ? &car : nullptr);
    gameref_set_type(*gameref_get(&car), pack ? id(pack, 6) : 0);
  };
  auto children = [&](uint32_t category) {
    Object root;
    gameref_set_type(*gameref_upsert(&root), id(parts, category));
    auto next = f.registry.invoke("java.util.resource.ResourceRef", "getFirstChild",
                                 "()Ljava.util.resource.ResourceRef;", &root, {});
    std::vector<uint32_t> result;
    std::set<uint32_t> seen;
    while (next.tag == ValueTag::Obj && next.v.o) {
      const auto* state = gameref_get(next.v.o);
      SLRR_REQUIRE(state && seen.insert(state->type_id).second && result.size() < 16);
      result.push_back(static_cast<uint32_t>(state->type_id));
      next = f.registry.invoke("java.util.resource.ResourceRef", "getNextChild",
                               "()Ljava.util.resource.ResourceRef;", next.v.o, {});
    }
    gameref_remove(&root);
    return result;
  };
  select_car(0);
  SLRR_REQUIRE(children(0xf243) == std::vector<uint32_t>({id(parts, 0x10), id(first, 1), id(second, 1)}));
  SLRR_REQUIRE(children(0xf242) == std::vector<uint32_t>({id(parts, 0x11), id(first, 2), id(second, 2)}));
  select_car(first);
  // Direct scripted parts from other car packs are Java collector candidates.
  // Only their unscripted model folders are excluded; own-car ordering stays.
  SLRR_REQUIRE(children(0xf243) == std::vector<uint32_t>({id(parts, 0x10), id(second, 1), id(first, 1)}));
  SLRR_REQUIRE(children(0xf246) == std::vector<uint32_t>({id(second, 4), id(first, 4)}));
  SLRR_REQUIRE(children(0xf242) == std::vector<uint32_t>({id(parts, 0x11), id(first, 2)}));
  select_car(second);
  SLRR_REQUIRE(children(0xf243) == std::vector<uint32_t>({id(parts, 0x10), id(first, 1), id(second, 1)}));
  SLRR_REQUIRE(children(0xf242) == std::vector<uint32_t>({id(parts, 0x11), id(second, 2)}));
  select_car(0);
  SLRR_REQUIRE(children(0xf243).size() == 3);
  gameref_clear();
  std::puts("PASS scripted cross-car catalog entries, folder filtering, own-car order and repeated car changes");
}
void duplicate_ids_keep_their_canonical_parent() {
  Fixture f;
  write_pack(f.root / "parts.rpk", {}, {
    {0, 0xf24b, ""}, {0, 0x0282, ""},
    {0xf24b, 0xd282, "script orange.class\n"},
    {0xf24b, 0xd285, "script green.class\n"},
    {0x0282, 0xd282, ""}, // Stock-like duplicate folder in another category.
    {0x0282, 0xf282, "script header.class\n"},
    {0x0282, 0xf282, "script shadow.class\n"}, // Same-parent duplicates looped.
    {0x0282, 0x1234d282, ""}, // Lookup and runtime IDs both use local16.
    {0x0282, 0xf285, "script other_header.class\n"},
    {0, 0xf290, "script parentless.class\n"},
    {0x0282, 0xf290, "script shadow_parentless.class\n"},
    {0xf291, 0xf291, "script self_parent.class\n"},
    {0x0282, 0xf291, "script shadow_self_parent.class\n"}});
  const int pack = f.packs.open_lib("parts.rpk");
  const auto id = [pack](uint32_t local) { return RpkIndex::make_full_id(pack, local); };
  const auto neons = id(0xf24b), exhaust = id(0x0282);
  SLRR_REQUIRE(f.packs.pack_by_id(pack)->entries.size() == 13);
  const std::vector<uint32_t> expected = {id(0xf282), id(0xf285)};
  SLRR_REQUIRE(f.packs.children_of(neons) == std::vector<uint32_t>({id(0xd282), id(0xd285)}));
  SLRR_REQUIRE(f.packs.children_of(exhaust) == expected);
  SLRR_REQUIRE(f.packs.resolve(id(0xd282))->super_id == 0xf24b);
  SLRR_REQUIRE(f.packs.payload_prop(id(0xd282), "script") == "orange.class");
  SLRR_REQUIRE(f.packs.payload_prop(id(0xf282), "script") == "header.class");

  register_resref_natives(f.vm, f.packs, f.sections);
  Object root;
  gameref_set_type(*gameref_upsert(&root), exhaust);
  auto node = f.registry.invoke("java.util.resource.ResourceRef", "getFirstChild",
                               "()Ljava.util.resource.ResourceRef;", &root, {});
  std::vector<uint32_t> walked;
  while (node.tag == ValueTag::Obj && node.v.o) {
    const auto* state = gameref_get(node.v.o);
    SLRR_REQUIRE(state && walked.size() < expected.size());
    walked.push_back(static_cast<uint32_t>(state->type_id));
    const auto* entry = f.packs.resolve(walked.back());
    SLRR_REQUIRE(entry && f.packs.resolve_embedded_id(pack, entry->super_id) == exhaust);
    node = f.registry.invoke("java.util.resource.ResourceRef", "getNextChild",
                             "()Ljava.util.resource.ResourceRef;", node.v.o, {});
  }
  SLRR_REQUIRE(walked == expected);
  auto array = f.registry.invoke("java.util.resource.ResourceRef", "getChildNodes",
                                "()[Ljava.util.resource.ResourceRef;", &root, {});
  SLRR_REQUIRE(array.tag == ValueTag::Obj && array.v.o && array.v.o->slots.size() == expected.size());
  for (size_t i = 0; i < expected.size(); ++i)
    SLRR_REQUIRE(static_cast<uint32_t>(gameref_get(array.v.o->slots[i].v.o)->type_id) == expected[i]);

  // Rebuilding after registration retains the policy and distinct pack IDs.
  write_pack(f.root / "late.rpk", {"parts.rpk"}, {{0x00010282, 0xf282, "script late.class\n"}});
  const int late = f.packs.open_lib("late.rpk");
  auto with_late = expected;
  with_late.push_back(RpkIndex::make_full_id(late, 0xf282));
  SLRR_REQUIRE(f.packs.children_of(exhaust) == with_late);
  SLRR_REQUIRE(f.packs.children_of(neons) == std::vector<uint32_t>({id(0xd282), id(0xd285)}));
  gameref_clear();
  std::puts("PASS canonical duplicate-ID parents, finite sibling walk, array enumeration and child-cache rebuild");
}
}  // namespace

int main() {
  const standalone::Test tests[] = {scripted_parts_survive_other_car_filter,
                                   duplicate_ids_keep_their_canonical_parent};
  return standalone::run("catalog_resources", tests);
}
