# Decisions

Record architecture and build-direction decisions here.

Start with the active direction: premade pill carousel, Flutter mobile app, XIAO ESP32-C6 controller, and Grove servo pusher/ratchet for the first actuator path.

## Current decisions

- Use Flutter/Dart for the Android and iOS app. Android can be either the embedded robot phone or a personal phone; iOS can only be a personal phone.
- Use Drift/SQLite for local app settings, reminder schedules, cached auth state, and dose log events. The ESP32 controller should not run SQLite.
- Keep reminder add/edit/delete and enabled/disabled state local until notification scheduling is wired behind the app-owned reminder interface.
- Keep Google sign-in behind an app-owned auth interface using `google_sign_in`; do not add Firebase, Supabase, or cloud sync until the backend direction is chosen.
- Keep real BLE out of the app until `docs/protocol.md` defines command, ACK/NACK, status, and event messages.
- Keep controller dispense success separate from dose taken confirmation. Servo movement or a simulated dispense event must not mark a dose taken.
