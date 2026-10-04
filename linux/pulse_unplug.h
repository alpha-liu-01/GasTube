#ifndef GASTUBE_PULSE_UNPLUG_H_
#define GASTUBE_PULSE_UNPLUG_H_

#include <flutter_linux/flutter_linux.h>

// Watch Pulse card ports. A wired headphone or headset that was available and
// then is not asks Dart to pause. The native socket is the one the audio
// policy already allows.
void gastube_pulse_unplug_attach(FlView* view);

#endif
