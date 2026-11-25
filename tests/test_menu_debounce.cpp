#include "save_io_fixture.hpp"
#include "slrr/script_compiler.hpp"
#include "slrr/host_input.hpp"
#include "slrr/scene_presentation.hpp"
#include <cmath>
#include <thread>
using namespace slrr;
void debounce(){
 Fixture f;fs::create_directories(f.root/"probe/src");
 std::ofstream(f.root/"probe/src/Handler.java")<<"package probe; public class Handler { public native void osdCommand(int command); }";
 auto report=script_compile_all(f.root.string(),"probe");SLRR_REQUIRE(report.failed==0);
 SLRR_REQUIRE(f.vm.load_class_file((f.root/"probe/Handler.class").string()));
 auto* handler=f.vm.new_object("probe.Handler");
 Object controller,menu,cancel,driving,select;
 controller.input=std::make_unique<ControllerInput>();
 int calls=0;
 f.registry.register_method("probe.Handler","osdCommand","(I)V",[&](Object*,const std::vector<Value>&){++calls;return Value::make_void();});
 auto add=[&](Object& key,int axis,int flags,int events){key.fields["command"]=Value::make_int(axis);host_input_create_hotkey(f.vm,&key,handler,nullptr,axis,flags,events);};
 auto check=[&](){host_input_check_hotkeys(f.vm,&controller,nullptr);};
 add(menu,36,1,1);add(cancel,35,1,3);add(driving,28,1,3);add(select,34,1,1);
 controller.input->forced_axes[36]=1;check();SLRR_REQUIRE(calls==1);
 for(int i=0;i<20;++i)check();SLRR_REQUIRE(calls==1); // held key
 controller.input->forced_axes[36]=0;check();
 // A second dialog uses CANCEL instead of MENU for the same Escape action.
 controller.input->forced_axes[35]=1;check();SLRR_REQUIRE(calls==1);
 controller.input->forced_axes[35]=0;check();SLRR_REQUIRE(calls==2); // release is delivered
 controller.input->forced_axes[28]=1;check();controller.input->forced_axes[28]=0;check();SLRR_REQUIRE(calls==4); // driving unaffected
 controller.input->forced_axes[34]=1;check();SLRR_REQUIRE(calls==5); // accept independent
 controller.input->forced_axes[34]=0;check();controller.input->forced_axes[34]=1;check();SLRR_REQUIRE(calls==5);
 std::this_thread::sleep_for(std::chrono::milliseconds(275));
 controller.input->forced_axes[35]=1;check();SLRR_REQUIRE(calls==6);
 // Physical Escape shares the virtual cancel debounce window.
 Object physical;add(physical,1,0,1);host_input_key(1,true);check();SLRR_REQUIRE(calls==6);host_input_key(1,false);check();
 host_input_forget(handler);host_input_clear_keys();
 std::puts("PASS held input, shared MENU/CANCEL/physical Escape debounce, release, driving and independent accept");
}

// #295: loading and section boundaries cancel latched and held pointer input.
void pointer_gestures(){
 auto& in=host_input();
 in.part_click=in.world_press=in.world_button=true;in.world_release=false;
 const uint32_t epoch=in.pointer_epoch;
 host_input_cancel_pointer_gestures();
 SLRR_REQUIRE(!in.part_click&&!in.world_press&&!in.world_button&&in.world_release);
 SLRR_REQUIRE(in.pointer_epoch==epoch+1);
 in.world_release=false;
 {
  SceneTransitionScope outer(true);SLRR_REQUIRE(in.pointer_epoch==epoch+2);
  in.part_click=true;
  {SceneTransitionScope inner(true);SceneTransitionScope off(false);}
  SLRR_REQUIRE(in.pointer_epoch==epoch+2&&in.part_click); // nested scopes are one boundary
 }
 SLRR_REQUIRE(in.pointer_epoch==epoch+3&&!in.part_click);
 std::puts("PASS click latch, world button and held gestures cancelled at loading/section boundaries");
}
// #296: arrow-key look is the controller's CAMTURNSET binding, not a raw key.
void camera_look_axes(){
 Object controller;controller.input=std::make_unique<ControllerInput>();
 host_input_clear_keys();host_input_key(0xcb,true);
 SLRR_REQUIRE(host_input_camera_axis(&controller,7)==0.f); // DRIVERSET: no look binding
 SLRR_REQUIRE(host_input_camera_axis(nullptr,7)==0.f);
 controller.input->bindings.push_back({7,0,0xcb,0.f,1.f,0.f,.005f});
 controller.input->bindings.push_back({7,1,0,-1.f,1.f,-1.f,1.f}); // mouse look: the host drag owns it
 SLRR_REQUIRE(std::abs(host_input_camera_axis(&controller,7)-.005f)<1e-6f);
 SLRR_REQUIRE(host_input_camera_axis(&controller,8)==0.f);
 host_input_clear_keys();
 SLRR_REQUIRE(host_input_camera_axis(&controller,7)==0.f);
 std::puts("PASS look keys follow controller bindings");
}

int main(){const standalone::Test tests[]={debounce,pointer_gestures,camera_look_axes};return standalone::run("menu_debounce",tests);}
