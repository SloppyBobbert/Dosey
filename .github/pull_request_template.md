## Scope

What changed, and why? Link the issue if applicable.

## Verification

- [ ] I ran the relevant checks, or explained why they do not apply.
- [ ] I included concise evidence: test output, build result, screenshots, or
      supervised bench observations, if applicable.
- [ ] I separated compile-tested behavior from physical validation, if
      applicable.

## Safety and data effects

- [ ] I considered dose state, inventory, controller movement, and local
      medication-data effects, if applicable.
- [ ] I confirmed inventory changes only after explicit taken confirmation.
- [ ] I confirmed missed-dose warning acknowledgment is seen-only and changes
      neither dose state nor inventory.
- [ ] I confirmed changes never advise double dosing and preserve: `This dose
      was missed. Follow your prescription instructions or ask your caregiver,
      pharmacist, or doctor.`
- [ ] I confirmed ambiguous movement, jams, cup/lid faults, power interruption,
      and disconnects fail safe into needs-review or equivalent.
- [ ] I did not add real medication, patient, account, or secret data.
- [ ] Hardware testing, if applicable, used fake pills only and did not treat
      movement as proof of delivery or intake.

## Deployment impact

- [ ] I described any pairing, authentication, authorization, environment, or
      deployment effect, if applicable.
- [ ] I noted any rollout, rollback, or manual verification needed, if
      applicable.
