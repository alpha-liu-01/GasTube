#include "my_application.h"

#ifdef GASTUBE_UBUNTU_TOUCH
extern "C" int gastube_ubuntu_touch_main(int argc, char** argv);
#endif

int main(int argc, char** argv) {
#ifdef GASTUBE_UBUNTU_TOUCH
  return gastube_ubuntu_touch_main(argc, argv);
#else
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
#endif
}
