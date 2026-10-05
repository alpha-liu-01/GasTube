#ifndef GASTUBE_PULSE_UNPLUG_H_
#define GASTUBE_PULSE_UNPLUG_H_

#include <flutter_linux/flutter_linux.h>

// Watch Pulse. A wired headset port dropping out, a USB audio card going
// away, or the droid sink leaving output-usb_device asks Dart to pause. The
// native socket is the one the audio policy already allows.
void gastube_pulse_unplug_attach(FlView* view);

#endif
