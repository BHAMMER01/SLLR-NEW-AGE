#pragma once

#include "slrr/host_input.hpp"

namespace slrr {
// Cooperative lifecycle calls can yield after destroying the active camera.
// Keep the last complete frame through section changes; loading plates may
// still be presented, and input continues to pump.
inline int scene_transition_depth = 0;
inline bool scene_transition_presentable = false;
inline bool scene_transition_active() { return scene_transition_depth != 0; }
inline bool scene_transition_blocks_presentation() {
  return scene_transition_active() && !scene_transition_presentable;
}
inline void scene_transition_loading_finished() {
  scene_transition_presentable = true;
}
class SceneTransitionScope {
 public:
  explicit SceneTransitionScope(bool active) : active_(active) {
    if (active_) {
      // A click held into a section change must not land in the next one.
      if (scene_transition_depth++ == 0) host_input_cancel_pointer_gestures();
      scene_transition_presentable = false;
    }
  }
  ~SceneTransitionScope() {
    if (active_ && --scene_transition_depth == 0) host_input_cancel_pointer_gestures();
  }
  SceneTransitionScope(const SceneTransitionScope&) = delete;
  SceneTransitionScope& operator=(const SceneTransitionScope&) = delete;
 private:
  bool active_;
};
}  // namespace slrr
