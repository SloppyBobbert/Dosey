---
name: Firmware or hardware issue
about: Report a controller, sensor, servo, BLE, or physical prototype issue
title: "[firmware/hardware] "
labels: ''
assignees: ''
---

## Scope

Identify the controller path, hardware configuration, firmware environment, and
protocol command or event involved.

## Reproduction or evidence

List the supervised steps, expected and observed behavior, serial/BLE logs, and
relevant build or test output. Do not include credentials or personal data.

## Validation

State host tests, firmware builds, or bench-runbook gates completed. Separate
compile-tested behavior from physically observed behavior.

## Safety impact

Describe any jam, unexpected movement, timeout, reset, disconnect, power, cup,
or sensor concern. Stop testing on faults. Use fake pills only; movement does
not prove delivery, correctness, or intake.
