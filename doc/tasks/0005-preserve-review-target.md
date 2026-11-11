# Task 0005: Preserve the insertion review target for undo and edit

**Status:** done
**Created:** 2026-11-10
**Scope ref:** Sources/FalaCore/UI/InsertionReviewController.swift
**Evidence ref:** doc/research/0011-ground-insertion-review-target.md
**Owner:** replacement_delivery
**Execution:** AFK

## Context

The review bubble retains an application's identity, but dismissal clears it before the asynchronous Undo/Edit action uses it. The real controller regression fixture reproduced undo/replacement without target reactivation. This is a bounded lifetime bug in existing actions, not a new history, Copy, persistence or review UI feature.

## Acceptance Criteria

- [x] Undo and Apply Edit preserve the captured target across panel dismissal and request reactivation before calling TextInserting.
- [x] Neither action calls TextInserting if the target is absent or reactivation fails; learning does not run on a failed edit.
- [x] The default AppKit path checks activate(options:) success and the frontmost process after the existing120ms wait; no claim of atomic focus ownership is made.
- [x] Edited text trimming and existing learning remain covered; dismiss alone does not activate or edit.
- [x] Tests invoke real InsertionReviewView callbacks through the real controller, with fake presentation/activation/wait and inserter; no real panel, clipboard or focus modification.
- [x] Fresh-context review and orchestrated final gate complete; real AppKit focus remains explicitly untested, not inferred from these tests.

## Plan

- [x] Record four-source ground, test seam and falsifiable hypotheses; reproduce before fixing ordering.
- [x] Preserve the action-local target and fail closed when it cannot be reactivated.
- [x] Run focused controller/flow/learning cases and lint; retain exact patch for independent review.
- [x] Integrate after review; this correction does not itself change release/version/platform policy.

## Notes

- 2026-11-10 — Base86ca327, isolated branchcodex/fala-insertion-target. Ground/plan recorded on disk before the experiment; no prior planning-commit ancestry claim. Ranked hypotheses: H1 dismiss clears the target; H2 capture provider is nil; H3 asynchronous Task does not execute. Actual RED in the original action ordering:6cases/12assertion failures/0unexpected; successful action events lacked activation, while nil/failure controls still edited. H1 confirmed; H2/H3 falsified by the known current-process provider and completed inserter operation.
- Fixed by capturing the application before dismiss and passing it into the asynchronous reactivation helper; actions return before undo/replace on nil or failed reactivation. Internal dependency seams preserve the public constructor and default panel behavior. Default reactivation retains the120ms delay and observes frontmost PID before allowing an operation; the observation can still race a later external focus change and is not an atomic guarantee.
- Final selected28tests/0failures (seven controller, two flow,19learner),0.565seconds execution. Strict lint covers the two changed Swift files. Logs `.agentic/reviews/insertion-target-red.log`, `insertion-target-green-final.log`, `insertion-target-lint-final.log`. Full package gate, review, live focus behavior and any release remain pending; no installed app or real user content was touched. Dependency cache compilation was isolated, not a release assembly.

- Final local closure: independent `/root/review_insertion_target` reviewed full patch `6fe604521c014cecb7e50c1a1e7b37fcc8d1f59809bf25f736f1ed75e6c5777c`, source/test patch `ea89cc6bc36faf7fae2ec5328d48de2f24aa6a81f1fa0cc9ab454e8521cf2b3b`; Standards and Spec both “ship as-is”, zero blockers/concerns. It inspected real callbacks, target capture before dismissal, activation→operation, nil/false controls, learning and default presentation; reused actual RED/GREEN/lint logs without modifying the tree. No source findings were omitted.
- Combined canonical `make check` passed324XCTest cases (322passed,2optional skipped), strict lint194files/0violations. Isolated NEXT candidate assembled successfully at `.build/verification/fala-priority-platform/Fala.app`; codesign strict, Info/Mach-O minimum27.2.1 and CLIhelp passed. One existing cached Ultra file transcription passed offline; one actual packaged Metal kernel ran on GPU with expected synthetic result. These assembly checks do not validate live microphone/device failure cleanup or real application focus/insertion. No installation, new version, tag, upload or release. Public1.14 artifacts remain unchanged. Execution receipt `.agentic/reviews/priority-assembled-candidate-verification.json`; source inputs frozen with131hashes.
- This closes the implemented local correction only. Earlier pending-review/gate notes above are historical and superseded; live GUI/focus validation remains a stated limit, not an inferred PASS.

## Definition of Done

- [x] Regression observed and focused tests pass
- [x] Fresh-context review completed
- [x] Integrated gate and status closure recorded
