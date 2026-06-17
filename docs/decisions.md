# Decisions

Record architecture and build-direction decisions here.

## Current decisions

- Use the premade Daviky pill carousel as the dose storage and presentation base. Each compartment holds one scheduled dose; Dosey does not count individual pills.
- Use a servo-driven pusher as the main actuator path. The servo has tested strong enough, so stepper motors and drivers are future fallbacks only.
- Add a ratchet, physical stop, or anti-backdrive feature so the carousel does not roll backward after each one-slot push.
- Use the Daviky chute and cup area for dose presentation.
- Build a fully LEGO body around the working mechanism. The LEGO shell is the current direction, not a temporary mockup before 3D printing.
- Use Flutter/Dart for the Android and iOS app. Android can be the embedded robot phone or a personal phone; iOS can only be a personal phone.
- Treat the mounted Android phone as Dosey's brain, face, speaker, reminder system, and caregiver communication point.
- Keep the XIAO controller simple: servo movement, PIR, LEDs, buzzer/vibration, buttons, basic sensors, Bluetooth messages, heartbeat/status replies, and error codes only.
- Keep medication schedules, medication names, refill logic, dose history, PIN rules, caregiver logic, voice, AI, and medical-safety decisions in the phone app.
- Use Drift/SQLite for local app settings, reminder schedules, cached auth state, and dose log events. The ESP32 controller should not run SQLite.
- Keep reminder add/edit/delete and enabled/disabled state local until notification scheduling is wired behind the app-owned reminder interface.
- Keep Google sign-in behind an app-owned auth interface using `google_sign_in`; do not add Firebase, Supabase, or cloud sync until the backend direction is chosen.
- Keep real BLE out of the app until `docs/protocol.md` defines command, ACK/NACK, heartbeat, status, and event messages.
- Keep controller dispense success separate from dose visibility and dose taken confirmation. Servo movement or a simulated dispense event must not mark a dose taken.

## To confirm

- Final XIAO board model. Use the generic XIAO ESP32 controller direction until the ESP32S3 versus ESP32-C6 choice is verified against the hardware.
- Final Grove expansion board/shield. The updated plan replaces the old XIAO Expansion Board direction with a Grove expansion board/shield that has enough ports.
- Whether the Daviky cup is practical as-is or needs a LEGO-supported cup opening.
