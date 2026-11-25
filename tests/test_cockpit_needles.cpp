// Dashboard pins (#301): chassis `cockpit_rpm` / `cockpit_speed` lines put a
// 3D pin on the dashboard, turned about its own posed Z axis by
// value * factor + offset limited to [low, high], as build 606 does
// (0x00444B60, 0x00444CB0, 0x0043C0A0). Uses the installed game data,
// read-only.
#include "save_io_fixture.hpp"
#include "slrr/gameref.hpp"
#include "slrr/part_runtime.hpp"
#include "slrr/race_runtime.hpp"
#include "slrr/scene_instances.hpp"
#include <array>
#include <cmath>
namespace slrr {
void spawn_ground_shell(Jvm &, const RpkIndex &, Object *);
}
using namespace slrr;
namespace {
bool close_to(float a, float b, float tolerance = 1e-4f) { return std::fabs(a - b) <= tolerance; }
bool same_matrix(const float *a, const PartMatrix &b, float tolerance = 1e-4f) {
  for (size_t i = 0; i < 16; ++i)
    if (!close_to(a[i], b[i], tolerance)) return false;
  return true;
}
PartMatrix needle_matrix(const CockpitNeedle &needle, double value) {
  PartPose pose = needle.pose;
  pose.rotation[2] += cockpit_needle_angle(needle, value);
  return part_pose_matrix(pose);
}
const CockpitNeedle &gauge(const PartConfig &cfg, CockpitGauge g) {
  return cfg.cockpit[static_cast<size_t>(g)];
}
// The chassis RenderRef child drawing that pin.
GameRefState *pin(Object *car, uint32_t resource, void **key = nullptr) {
  auto *node = gameref_get(car);
  if (!node) return nullptr;
  GameRefState *found = nullptr;
  for (void *child : node->children) {
    auto *render = gameref_get(child);
    if (!render || render->kind != GameRefKind::RenderRef ||
        static_cast<uint32_t>(render->type_id) != resource)
      continue;
    SLRR_REQUIRE(!found);  // one pin per gauge
    found = render;
    if (key) *key = child;
  }
  return found;
}
uint32_t chassis_type(RpkIndex &packs, const char *file) {
  const auto pack = packs.open_lib(file);
  for (const auto &e : packs.pack_by_id(pack)->entries) {
    const auto id = RpkIndex::make_full_id(pack, e.type_id);
    const auto cfg = load_part_config(packs, id);
    if (cfg.valid && cfg.native_kind == "car") return id;
  }
  return 0;
}
} // namespace

void parse_cockpit_lines() {
  const auto cfg = parse_part_config(
      "render 0x0003001C\n"
      "cockpit_speed\t-0.448 0.120 -0.510\t0.000 0.000 0.000 0x00020037 2.2 -0.009    -2.2 2.2\n"
      "cockpit_rpm\t-0.328 0.120 -0.510\t0.1 -0.35 0.2 0x00020037\n"
      "osd_rpmpin 0x0002BAA5 1.830 -0.988 0.000 3.94 -0.00045 -0.80 3.74\n");
  SLRR_REQUIRE(cfg.valid && cfg.errors.empty() && cfg.unknown.empty());
  const auto &speed = gauge(cfg, CockpitGauge::Speed);
  SLRR_REQUIRE(speed.defined && speed.resource == 0x00020037);
  SLRR_REQUIRE(close_to(speed.pose.position[0], -.448f) && close_to(speed.pose.position[2], -.51f));
  SLRR_REQUIRE(close_to(speed.offset, 2.2f) && close_to(speed.factor, -.009f) &&
               close_to(speed.low, -2.2f) && close_to(speed.high, 2.2f));
  // Absent fields keep build 606's defaults: 2.2, -0.0005 rpm, -2.2, 2.2.
  const auto &rpm = gauge(cfg, CockpitGauge::Rpm);
  SLRR_REQUIRE(rpm.defined && close_to(rpm.pose.rotation[1], -.35f));
  SLRR_REQUIRE(close_to(rpm.offset, 2.2f) && close_to(rpm.factor, -.0005f) &&
               close_to(rpm.low, -2.2f) && close_to(rpm.high, 2.2f));
  const auto defaults = parse_part_config("render 0x1\ncockpit_speed 0 0 0 0 0 0 0x00020037\n");
  SLRR_REQUIRE(close_to(gauge(defaults, CockpitGauge::Speed).factor, -.02f));
  // The overlay pin is a separate instrument and stays as it was.
  const auto &overlay = cfg.hud[static_cast<size_t>(HudSlot::RpmPin)];
  SLRR_REQUIRE(overlay.defined && close_to(overlay.needle[0], 3.94f) && close_to(overlay.needle[3], 3.74f));

  // A short or malformed instrument line loses its pin, not the chassis.
  const auto bad = parse_part_config(
      "render 0x1\ncockpit_rpm 0 0 0 0 0 0\ncockpit_speed 0 0 0 0 0 0 0x00020037 nope\n");
  SLRR_REQUIRE(bad.valid && bad.errors.empty() && bad.unknown.size() == 2);
  SLRR_REQUIRE(!gauge(bad, CockpitGauge::Rpm).defined && !gauge(bad, CockpitGauge::Speed).defined);

  // Angle: below low gives low, otherwise above high gives high.
  CockpitNeedle n;
  n.offset = 2.2f; n.factor = -.009f; n.low = -2.2f; n.high = 2.2f;
  SLRR_REQUIRE(close_to(cockpit_needle_angle(n, 0), 2.2f));
  SLRR_REQUIRE(close_to(cockpit_needle_angle(n, 100), 1.3f));
  SLRR_REQUIRE(close_to(cockpit_needle_angle(n, 1e6), -2.2f));
  SLRR_REQUIRE(close_to(cockpit_needle_angle(n, -1e6), 2.2f));
  SLRR_REQUIRE(close_to(cockpit_needle_angle(n, NAN), 2.2f));
  // Einvagen: offset 2.2 above high 1.5 rests at 1.5.
  n.factor = -.03f; n.low = -3.f; n.high = 1.5f;
  SLRR_REQUIRE(close_to(cockpit_needle_angle(n, 0), 1.5f));
  // Inverted bounds are not swapped: low wins below it, high above it.
  n.factor = 1.f; n.offset = 0.f; n.low = 1.f; n.high = -1.f;
  SLRR_REQUIRE(close_to(cockpit_needle_angle(n, 0), 1.f) && close_to(cockpit_needle_angle(n, 5), -1.f));
  std::puts("PASS cockpit needle lines parse with build 606 defaults and limits");
}

void stock_pins_follow_rpm_and_speed() {
  Fixture f;
  const auto game = fs::absolute("game");
  for (const auto &e : fs::recursive_directory_iterator(game))
    if (e.is_regular_file() && e.path().extension() == ".class") {
      auto out = f.root / fs::relative(e.path(), game);
      fs::create_directories(out.parent_path());
      fs::copy_file(e.path(), out);
    }
  f.packs.set_root(game.string());
  f.packs.open_all();
  rpk_set_active(&f.packs);
  SLRR_REQUIRE(f.vm.bootstrap_classpath());
  gameref_clear();
  register_lang_natives(f.vm, f.packs, f.sections);
  register_gameref_natives(f.vm, f.packs, f.sections);
  register_resref_natives(f.vm, f.packs, f.sections);
  register_renderref_natives(f.vm, f.packs, f.sections);
  register_part_natives(f.vm, f.packs);
  register_race_natives(f.vm, f.packs, f.sections);
  Object world, ground, brain;
  gameref_upsert(&world, GameRefKind::Dummy)->flags = kWorldTreeRoot;
  auto city = f.packs.open_lib("maps/city.rpk");
  auto *g = gameref_upsert(&ground, GameRefKind::GroundRef);
  g->type_id = RpkIndex::make_full_id(city, 1);
  gameref_set_parent(&ground, &world);
  gameref_upsert(&brain);
  scene_instances_set_resources(&f.packs);
  scene_instances_select(&world, nullptr, false);
  ground.class_name = "java.util.resource.GroundRef";
  spawn_ground_shell(f.vm, f.packs, &ground);
  scene_instances_enable_static_floor(false);
  auto graph = race_ground_roads(f.packs, &ground);
  SLRR_REQUIRE(graph);
  const auto &e = graph->edges().front();
  const auto start = e.points.front(), finish = e.points.back();
  const auto toward = e.points[1];
  const float yaw = std::atan2(-(toward[0] - start[0]), -(toward[2] - start[2]));

  // Baiern (flat pins) and Enula (pins pitched by -0.35 rad).
  for (const char *file : {"cars/racers/Baiern.rpk", "cars/racers/Enula.rpk"}) {
    const uint32_t type = chassis_type(f.packs, file);
    SLRR_REQUIRE(type);
    const auto cfg = load_part_config(f.packs, type);
    const auto &rpm = gauge(cfg, CockpitGauge::Rpm), &speed = gauge(cfg, CockpitGauge::Speed);
    SLRR_REQUIRE(rpm.defined && speed.defined);
    auto *vehicle = vehicle_spawn_stock(f.vm, f.packs, &ground, type);
    SLRR_REQUIRE(vehicle);
    auto *car = part_chassis(vehicle);
    SLRR_REQUIRE(car);
    gameref_set_matrix(car, start[0], start[1], start[2], yaw, 0, 0);
    part_park_chassis(car);
    part_physics_advance(1. / 60.);
    void *rpm_key = nullptr, *speed_key = nullptr;
    GameRefState *rpm_pin = nullptr, *speed_pin = nullptr;
    if (rpm.resource != speed.resource) {
      rpm_pin = pin(car, rpm.resource, &rpm_key);
      speed_pin = pin(car, speed.resource, &speed_key);
    } else {
      // Both gauges use the stock pin: tell them apart by position.
      size_t pins = 0;
      for (void *child : gameref_get(car)->children) {
        auto *render = gameref_get(child);
        if (!render || static_cast<uint32_t>(render->type_id) != rpm.resource) continue;
        ++pins;
        const float *m = render->local_matrix;
        if (close_to(m[12], rpm.pose.position[0]) && close_to(m[14], rpm.pose.position[2])) {
          rpm_pin = render; rpm_key = child;
        } else if (close_to(m[12], speed.pose.position[0]) && close_to(m[14], speed.pose.position[2])) {
          speed_pin = render; speed_key = child;
        }
      }
      SLRR_REQUIRE(pins == 2);
    }
    SLRR_REQUIRE(rpm_pin && speed_pin && rpm_pin->matrix_override && speed_pin->matrix_override);
    SLRR_REQUIRE(scene_instances_geometry(rpm.resource));
    // Parked, engine off: both pins rest at the clamped offset.
    SLRR_REQUIRE(same_matrix(rpm_pin->local_matrix, needle_matrix(rpm, 0)));
    SLRR_REQUIRE(same_matrix(speed_pin->local_matrix, needle_matrix(speed, 0)));
    std::printf("COCKPIT %s rest: rpm angle %.3f speed angle %.3f\n", file,
                cockpit_needle_angle(rpm, 0), cockpit_needle_angle(speed, 0));

    // Driving under autonomous control: the pins follow the car's own values.
    race_brain_command(f.packs, &brain, "controllable " + std::to_string(gameref_make_live(car)));
    f.vm.set_static("java.util.resource.GameRef", "EVENT_COMMAND", Value::make_int(0x10));
    auto *bot = f.vm.new_object("java.game.Bot");
    bot->fields["car"] = Value::make_obj(vehicle);
    bot->fields["brain"] = Value::make_obj(&brain);
    bot->fields["world"] = Value::make_obj(&ground);
    bot->fields["traffic_id"] = Value::make_int(0);
    auto *racer = f.vm.new_object("java.game.Racer");
    racer->fields["car"] = Value::make_obj(vehicle);
    auto *destination = f.vm.new_object("java.lang.Vector3");
    destination->fields["x"] = Value::make_float(finish[0]);
    destination->fields["y"] = Value::make_float(finish[1]);
    destination->fields["z"] = Value::make_float(finish[2]);
    f.vm.invoke("java.game.Bot", "startRace", "(Ljava.lang.Vector3;Ljava.game.Racer;)V",
                {Value::make_obj(bot), Value::make_obj(destination), Value::make_obj(racer)}, false);
    for (int i = 0; i < 240; ++i)
      part_physics_advance(1. / 60.);
    PartPhysicsState state;
    SLRR_REQUIRE(part_physics_state(car, state));
    std::printf("COCKPIT %s driving %.1f km/h %.0f rpm: rpm angle %.3f speed angle %.3f\n", file,
                state.speed_kph, state.rpm, cockpit_needle_angle(rpm, state.rpm),
                cockpit_needle_angle(speed, state.speed_kph));
    SLRR_REQUIRE(state.speed_kph > 5 && state.rpm > 500);
    SLRR_REQUIRE(same_matrix(rpm_pin->local_matrix, needle_matrix(rpm, state.rpm), 1e-3f));
    SLRR_REQUIRE(same_matrix(speed_pin->local_matrix, needle_matrix(speed, state.speed_kph), 1e-3f));
    SLRR_REQUIRE(!same_matrix(speed_pin->local_matrix, needle_matrix(speed, 0), 1e-3f));
    // The pin turns about its own posed Z axis: that axis and the pivot
    // stay where the cfg pose puts them, whatever the angle.
    const auto rest = part_pose_matrix(speed.pose);
    for (int i = 8; i < 11; ++i) SLRR_REQUIRE(close_to(speed_pin->local_matrix[i], rest[i], 1e-4f));
    for (int i = 12; i < 15; ++i) SLRR_REQUIRE(close_to(speed_pin->local_matrix[i], rest[i], 1e-5f));

    // Car replacement and scene exit: the pins go with their chassis.
    SLRR_REQUIRE(part_destroy(car));
    SLRR_REQUIRE(!gameref_get(rpm_key) && !gameref_get(speed_key));
    part_physics_advance(1. / 60.);
  }

  scene_instances_select(nullptr, nullptr, false);
  scene_instances_set_resources(nullptr);
  scene_instances_enable_static_floor(false);
  gameref_clear();
  rpk_set_active(nullptr);
  std::puts("PASS stock dashboard pins follow rpm and speed and leave with their car");
}

// `shifter x y z` (build 606 cfg handler 0x00444990): the lever knob that the
// gear-shift gesture reaches for. No line keeps the origin, as the exe does.
void parse_shifter_line() {
  const auto wreck = parse_part_config("render 0x1\nshifter         0.000  -0.039 0.020\n");
  SLRR_REQUIRE(wreck.valid && wreck.unknown.empty());
  SLRR_REQUIRE(close_to(wreck.shifter[1], -.039f) && close_to(wreck.shifter[2], .02f));
  const auto racer = parse_part_config("render 0x1\n");
  SLRR_REQUIRE(racer.shifter[0] == 0.f && racer.shifter[1] == 0.f && racer.shifter[2] == 0.f);
  std::puts("PASS shifter line parses, origin by default");
}

int main() {
  const standalone::Test tests[] = {parse_cockpit_lines, stock_pins_follow_rpm_and_speed,
                                    parse_shifter_line};
  return standalone::run("cockpit_needles", tests);
}
