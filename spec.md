# Specification — Stopping & Parking Expert System

> Course project, Expert Systems (Sisteme Expert), year IV.
> Maneuver: **oprire + staționare** (stopping + parking).
> Reference implementation this project builds on: the overtaking expert system
> (code in `Overtaking-Expert-System/`).
> The analysis of that system is kept in [docs/spec-overtaking-reference.md](docs/spec-overtaking-reference.md).

This document specifies what the new system must do. Everything marked **(inherited)** is reused unchanged from
the overtaking system; everything marked **(new)** has to be written.

---

## 1. Purpose

A rule-based **driving agent** for an autonomous car, written in **CLIPS**. At every time frame it receives the
facts produced by the car's sensors and answers two questions:

1. Is **stopping** (oprire) allowed here and now?
2. Is **parking** (staționare) allowed here and now?

The decision is based on a **simplified** version of the Romanian traffic code (10 rules, §6).

### 1.1 Definitions used by the system

| Term | Meaning (simplified from the Romanian code) |
|---|---|
| **Oprire** (stopping) | Voluntary immobilisation of the vehicle for a short time (≤ 5 min), e.g. to let people get in/out or to load/unload, with the driver staying at the vehicle. |
| **Staționare** (parking) | Voluntary immobilisation longer than 5 min, or with the driver leaving the vehicle. |
| Relation | Every place where **stopping is prohibited**, **parking is prohibited too**. Some places prohibit only parking. |

The agent does not receive the intended duration; it reports the status of **both** maneuvers for every frame.

## 2. Course requirements (from the lecture notes)

### 2.1 Data model

| Requirement | How it is met |
|---|---|
| Input is a series of **frames** (clips); a frame is one instant holding a set of **facts** (sensor readings). | A frame is a file of `ag_percept` facts **(inherited)**. |
| Facts are *object – property – value* (e.g. "object 1 is a car", "object 1 relative position left", "distance from object 2"). | Same fact shape **(inherited)**, new vocabulary (§5). |
| Each **folder** is one **test scenario** holding *k* frames. | `percepts/sceneN/t1.clp … tk.clp`. |
| **3 scenarios per student, 20–30 frames per scenario.** | **6 scenarios × 20 frames** (§7). The overtaking project only had 10. |
| After the first frame is processed it is removed from working memory; intermediate data may be kept. | Percepts of frame *t* are retracted before *t+1* is loaded **(inherited)**. |
| Sensors have a **transfer time**; the car's **speed** is a per-frame sensor reading. | Timings in §4; `speed` is a per-frame fact (§5) and is used in the timing analysis (§8). |

### 2.2 Rules

* Model the traffic rules: given the frame, is the maneuver permitted?
* Simplifying assumption allowed: the maneuver is **permitted by default** and rules only veto it.
* The agent file (`DRIVER-AGENT.clp`) holds the rules and outputs *allowed / prohibited*.

### 2.3 Performance

* Measure the response time: debug mode on, decision time recorded per frame, **average decision time** over
  repeated runs, and relate it to the car's speed (§8).

### 2.4 Documentation (the deliverable)

* Sensors needed and their response times.
* **Syntax of the facts** and how to interpret the data.
* **Individual contributions** (rule *x* by student *k*, scenario *y* by student *l*).
* External references / bibliography, stating where each was used.

### 2.5 Grading order

1. Model the scenarios → model the facts.
2. Model the rules.
3. Documentation.

The project is run and checked for correct inference. **Submit on Moodle: documentation only**, file named
`nume_prenume`, **before the summer holiday**.

## 3. System architecture

Same three-module CLIPS design as the overtaking system **(inherited)**.

```
            ┌────────────────────────── MAIN ──────────────────────────┐
            │  secventa (PERCEPT-MANAGER AGENT)  — rotates, asserts tic │
            └───────────────┬───────────────────────────┬──────────────┘
                   focus     │                           │ focus
                             ▼                           ▼
              ┌──────────────────────────┐   ┌───────────────────────────────┐
              │     PERCEPT-MANAGER      │   │             AGENT             │
              │ delete old ag_percept    │   │ percepts → moment beliefs     │
              │ timp := timp + 1         │──▶│ veto rules → stop-banned /    │
              │ load-facts t<timp>.clp   │   │              park-banned      │
              └──────────────────────────┘   │ decide + print both maneuvers │
                                             │ print decision time, cleanup  │
                                             └───────────────────────────────┘
```

| Module | Role |
|---|---|
| `MAIN` | Rotates focus between the other modules via `secventa`; asserts `tic` when handing control to `PERCEPT-MANAGER`. |
| `PERCEPT-MANAGER` | Clears the previous frame, increments `timp`, runs `(load-facts "<dir>/t<timp>.clp")`. |
| `AGENT` | Reasoning, decision output, housekeeping, timing. |

### 3.1 Agent cycle (priorities) — what changes

| Salience | Rule | Status |
|---|---|---|
| 96 | `time_start` — `(tstart (time))` | inherited |
| 93 | `percepts_into_beliefs` — each `ag_percept` → `ag_bel` of type `moment` | inherited |
| 89 | `initCycle-stop-park` — asserts nothing banned; both maneuvers *allowed* by default | **new** (replaces `initCycle-overtaking`) |
| 0 | veto rules R1–R10 (§6) — assert `stop-banned` or `park-banned` | **new** |
| −10 | `decide-stopping` / `decide-parking` — turn the bans into the two decisions (§3.2) | **new** |
| −50 | `tell` — print one line per maneuver in `(ASK …)` | adapted |
| −85 | `hk-eliminate-momentan-current-bel` | inherited |
| −92 | `time_end` — print decision time | inherited |

### 3.2 Decision logic (new)

Veto rules **do not retract the default**. They only assert an intermediate belief, so several rules can fire
on the same frame without racing for the same fact (the overtaking design retracts one shared *allowed* fact):

```clips
(ag_bel (bel_type moment) (bel_pname stop-banned) (bel_pval yes) (bel_pobj ?cause))   ; stopping and parking banned
(ag_bel (bel_type moment) (bel_pname park-banned) (bel_pval yes) (bel_pobj ?cause))   ; parking only
```

`?cause` is the object (e.g. `elem2`) that triggered the ban, so the output can explain itself in debug mode.

| Condition | `stopping-maneuver` | `parking-maneuver` |
|---|---|---|
| a `stop-banned` belief exists | prohibited | prohibited |
| only `park-banned` exists | allowed | prohibited |
| neither | allowed | allowed |

Control facts: `(ASK stopping-maneuver)` and `(ASK parking-maneuver)` in `maneuverValidityASK.clp`
(the file already supports several `ASK` facts). Output lines:

```
AGENT stopping-maneuver allowed
AGENT parking-maneuver prohibited
```

Termination is the same as before: `(run ?*totalNrRules*)` with a per-scenario firing budget
**(inherited; to be recounted)** — see §11.

## 4. Sensors

Reused from the overtaking project **(inherited)**. A frame is extracted every **200 ms**; a scenario is
**20 frames = 4 s**. Timings from the original documentation; row/timing pairing recovered from PDF text
extraction order.

| Sensor | Purpose for stop/park | Response time |
|---|---|---|
| Rangefinder laser / LiDAR | distance to crossings, stations, obstacles, vehicles | < 5 ms |
| Ultrasonic sensors in mirrors | free space along the **right kerb**, blind spots | < 1 ms |
| Stereo-vision camera (front and rear) | max road depth → visibility; kerb and markings | 10–30 ms |
| PPP or RTK positioning | position (precision of centimetres) | < 5 ms |
| Advanced map system | static restrictions from position: stations, crossings, signs | 5 ms + 150 ms |
| Gyroscope | road slope / inclination | < 1 ms |
| Front camera + deep-learning classifier | classifies signs, stations, crossings, tracks | 16 ms + 150 ms |
| **Speed sensor** (new) | ego speed, one value per frame | not specified — to be documented |

Assumptions:

* Distances and visibility are in **centimetres**; speed in **km/h**.
* If the rangefinder reports its maximum distance, there is nothing nearby.
* Detected **free space** on the right is automatically large enough for the car (≥ 3.5 m long, as in the original).
* Buffers signal entry into a tunnel or under a bridge.
* `percept_pobj` can be any object name (`elem1`, `elem2`, …).

## 5. Fact syntax

### 5.1 Templates **(inherited, unchanged)**

```clips
(deftemplate PERCEPT-MANAGER::ag_percept (slot percept_pobj) (slot percept_pname) (slot percept_pval))
(deftemplate AGENT::ag_bel (slot bel_type) (slot bel_pname) (slot bel_pval) (slot bel_pobj))   ; bel_type: moment
(deftemplate PERCEPT-MANAGER::timp (slot valoare))
(deftemplate MAIN::tic)
```

### 5.2 Frame file layout

```clips
(ag_percept (percept_pobj ev)    (percept_pname isa)    (percept_pval eveniment))   ; the frame
(ag_percept (percept_pobj ego)   (percept_pname isa)    (percept_pval ego))         ; the car itself  (new)
(ag_percept (percept_pobj ego)   (percept_pname speed)  (percept_pval 40))          ; km/h            (new)
(ag_percept (percept_pobj elem1) (percept_pname partof) (percept_pval ev))
(ag_percept (percept_pobj elem1) (percept_pname isa)    (percept_pval road_elem))
… further properties of elem1 …
```

### 5.3 Properties by category

Dominant change versus the overtaking system: fewer vehicle facts, more road-element and sign facts.

**`isa ego`** (new) — the car. `speed`: number, km/h.

**`isa road_elem`** — stereo camera + DL classifier + maps

| `pname` | `pval` |
|---|---|
| `rel_dist` | number (cm); `0` = the car is on/at the element |
| `rel_pos` | `front`, `back`, `left`, `right`, `right_front`. Elements with `back` are already passed and do **not** trigger rules. |
| `has_type` | `intersection`\*, `crosswalk`, `railway_level_crossing`, `tram_station`, `tram_station_without_shelter`, `bus_station` |

\* Unlike the overtaking system, intersections are modelled as a plain `road_elem` of type `intersection`; the
`is_road` / `is_driven` attributes are not needed for stop/park.

**`isa road_nature`** — rangefinder + gyroscope + maps + stereo camera

| `pname` | `pval` |
|---|---|
| `has_visibility` | number (cm) |
| `has_type` | `curve`, `slope`, `fog`, `bridge`, `under_bridge`, `tunnel` |

*Use `road_nature` exactly — the hyphenated `road-nature` in the old overtaking data must not be copied.*

**`isa road_attribute`** — gyroscope + maps + DL classifier

| `pname` | `pval` |
|---|---|
| `rel_dist` | number (cm), optional |
| `rel_pos` | for `free_space`: `right` (the kerb side the car would stop on) |
| `has_type` | `tram_tracks`, `no_stopping_sign`, `no_parking_sign`, `free_space`, `discontinuous_strip`, `continuous_strip` |

**`isa vehicle`** — kept for realism (parked cars, traffic) but **not used** by any rule in this version
(`has_type car`, `bus`, `tram`, …; `rel_pos`, `rel_dist`).

Rule of thumb for modelling a frame: *to forbid something, a sensor must report it; the absence of
`free_space` on the right is itself a reportable condition (R10).*

## 6. Rule base (simplified Romanian code) — 10 rules

All rules live in `AGENT` (`DRIVER-AGENT.clp`). Each fires when its pattern matches in the current frame and
asserts a ban belief (§3.2). Distances use the sensor's centimetres. Thresholds are **modelling assumptions**
taken from the code in simplified form and should be checked against the current text of OUG 195/2002
(stopping and parking section) before submission.

| # | Rule name | Situation | Condition on beliefs | Stopping | Parking |
|---|---|---|---|---|---|
| R1 | `intersectie` | Intersection | `road_elem` type `intersection`, `rel_pos front`, `rel_dist` < 2500 (25 m) | ✗ | ✗ |
| R2 | `trecere_pietoni` | Pedestrian crossing | `road_elem` type `crosswalk`, `rel_pos front`, `rel_dist` < 2500 | ✗ | ✗ |
| R3 | `trecere_cale_ferata` | Railway level crossing | `road_elem` type `railway_level_crossing`, `rel_pos front`, `rel_dist` < 5000 (50 m) | ✗ | ✗ |
| R4 | `statie_transport_public` | Tram / bus station | `road_elem` type `tram_station`, `tram_station_without_shelter` or `bus_station`, `rel_pos` ∈ {front, right_front}, `rel_dist` < 2500 | ✗ | ✗ |
| R5 | `linii_tramvai` | Tram tracks on the carriageway | `road_attribute` type `tram_tracks` | ✗ | ✗ |
| R6 | `pasaj_pod_tunel` | Bridge, underpass, tunnel | `road_nature` type ∈ {`bridge`, `under_bridge`, `tunnel`} | ✗ | ✗ |
| R7 | `vizibilitate_redusa` | Reduced visibility | `road_nature` type ∈ {`curve`, `slope`}, `has_visibility` < 5000 | ✗ | ✗ |
| R8 | `semn_oprire_interzisa` | "No stopping" sign | `road_attribute` type `no_stopping_sign` | ✗ | ✗ |
| R9 | `semn_stationare_interzisa` | "No parking" sign | `road_attribute` type `no_parking_sign` | ✓ | ✗ |
| R10 | `fara_loc_pe_dreapta` | No room at the kerb | the frame contains **no** `road_attribute` `free_space` with `rel_pos right` | ✗ | ✗ |

✗ = banned (assert `stop-banned` for ✗/✗ rows, `park-banned` for R9), ✓ = unaffected.
Default (§3.1): both maneuvers allowed when no rule fires.

Notes on the design choices:

* **Fog** is *not* in R7: stopping in fog is allowed by this simplified model; fog is kept in the vocabulary
  because scenario 5 uses it as a "decoy" (see §7).
* R10 mirrors the "negated pattern" used in the overtaking rules (`not … free_space`).
* Rules R1–R7 depend on the element being **ahead** (`front`); once passed (`back`) the ban lifts.
* Vehicle-related rules (double parking, driveways, bus lanes) are intentionally left out to keep the code to
  10 rules; they are listed in §12 as possible extensions.

## 7. Scenarios and expected results

6 scenarios (3 per student) of **20 frames** each. Each frame has one decision pair. Notation: **S** = stopping,
**P** = parking; `Y` allowed, `N` prohibited. Unless a row says otherwise a `free_space right` is present in every
frame and the car drives at 30–50 km/h. A segment lists the frames it covers and the rule that causes the result.

| # | Story | Frames → (S, P), cause |
|---|---|---|
| 1 | **Residential street.** Free kerb, then a "no parking" sign, then free again. | 1–6 → Y,Y · 7–12 → **Y,N** (R9) · 13–20 → Y,Y |
| 2 | **Junction and crossing.** Intersection ahead, passed, then a pedestrian crossing. | 1–4 → Y,Y · 5–9 → **N,N** (R1, intersection < 25 m) · 10–12 → Y,Y · 13–17 → **N,N** (R2, crosswalk < 25 m) · 18–20 → Y,Y |
| 3 | **Public transport.** Tram station ahead, then tram tracks, then a bus station. | 1–5 → Y,Y · 6–11 → **N,N** (R4, tram station) · 12–14 → **N,N** (R5, tracks) · 15–17 → Y,Y · 18–20 → **N,N** (R4, bus station) |
| 4 | **Level crossing and bridge.** Railway crossing, then a bridge. | 1–3 → Y,Y · 4–9 → **N,N** (R3, crossing < 50 m) · 10–12 → Y,Y · 13–17 → **N,N** (R6, bridge) · 18–20 → Y,Y |
| 5 | **Mountain road.** Curve with low visibility, a fog patch, a slope, then a tunnel. | 1–4 → Y,Y · 5–9 → **N,N** (R7, curve, visibility 3000) · 10–12 → Y,Y (fog patch, visibility 2000, **no rule** — decoy) · 13–15 → Y,Y · 16–17 → **N,N** (R7, slope, visibility 2000) · 18–20 → **N,N** (R6, tunnel) |
| 6 | **Busy kerb.** Parked cars fill the kerb (no free space), then a free kerb with a "no stopping" sign, then free, then a "no parking" sign. | 1–4 → Y,Y · 5–9 → **N,N** (R10, no `free_space right`) · 10–13 → **N,N** (R8, free space present) · 14–16 → Y,Y · 17–20 → **Y,N** (R9) |

Coverage: every rule R1–R10 is the cause of at least one segment (R9 twice).

Acceptance: running a scenario prints, per frame, the two lines `AGENT stopping-maneuver …` and
`AGENT parking-maneuver …`, and both values equal the table. The textual description + the per-frame expected
result go into `scenes/scenariul N` (as before), one frame per entry, so they can later be compared automatically.

## 8. Performance measurement

* `?*ag-measure-time*` enables a `<M> AGENT Decision time: x sec.` line per frame (inherited; `time_start` at
  salience 96 → `time_end` at −92).
* Method (inherited from `DocuSE.ods`): 10 runs per frame per scenario; mean and standard deviation per frame,
  then per scenario. For 20-frame scenarios the sheet needs 20 rows per scenario.
* Baseline from the overtaking system: **~2×10⁻⁵ s … 1.2×10⁻⁴ s** per frame. The stop/park system does two
  decisions and a slightly larger fact vocabulary, so expect the same order of magnitude.
* **Speed-aware check (new, required by the course notes):** distance the car covers while the agent decides is
  `d = v × t_decision`. At 50 km/h (13.9 m/s) and 120 µs this is ≈ 1.7 mm; the dominant delays are the sensors
  (up to 150 ms + 16 ms for the classifier path ≈ 2.3 m at 50 km/h), which must be reported next to the decision
  time to judge whether the car can still stop before a banned zone. The documentation reports, per scenario,
  the largest ban threshold (50 m for a railway crossing) against this total latency.

## 9. How to run

Requires CLIPS 6.x. From the project folder:

```
CLIPS> (batch "go")
```

`go` clears the environment, loads the modules in the same order as the overtaking system (headers, MAIN rules,
PERCEPT-MANAGER, belief copy + timer start, DRIVER-AGENT, decision/cleanup/timer end, initial facts, ASK facts),
then `(reset)` and `(run ?*totalNrRules*)`.

Choose a scenario by editing `headers.clp`: `?*perceptsDir*` (`./percepts/sceneN/`) and `?*totalNrRules*`
(**must be recounted** for the new rule set and 20-frame scenarios; see §11).

Debug switches are unchanged (`?*ag-in-debug*`, `?*ag-percepts-in-debug*`, `?*ag-measure-time*`, …).

## 10. Planned repository layout

```
spec.md                                   this document
docs/spec-overtaking-reference.md         analysis of the original overtaking system
Overtaking-Expert-System/                 original code (reference, unchanged)
StopPark-Expert-System/                   new system (to be created)
  go, headers.clp, MAIN-rules.clp, PERCEPT-MANAGER.clp      copied unchanged
  AddMomentBelifsGetStartTime.clp, TellDeleteMomentBelifsGetEndTime.clp   copied; tell adapted
  DRIVER-AGENT.clp                        R1–R10 + decision rules  (new)
  initials.clp, maneuverValidityASK.clp   initial + ASK facts (two maneuvers)
  percepts/scene1..6/t1..t20.clp          frames (new)
  scenes/scenariul 1..6                   scenario text + expected result per frame (new)
  docs: documentation (PDF) + timing spreadsheet
```

## 11. Lessons from the overtaking implementation to avoid

Details in [docs/spec-overtaking-reference.md](docs/spec-overtaking-reference.md) §11.

| Problem in the original | What to do here |
|---|---|
| Typos in fact values (`interection`, `bumpy` vs `bumpy_road`, `road-nature`, strip names in two orders) made rules silently dead. | Fix a vocabulary list (§5), reuse it verbatim in rules and frames; check every rule against at least one frame. |
| Shared `allowed` fact retracted by each veto rule. | Ban beliefs + separate decision rules (§3.2). |
| `?*totalNrRules*` hand-counted and edited per scenario. | Recount for the new rule set; better, stop the run when no frame file exists for `timp`. |
| Scenario switched by editing two lines in `headers.clp`. | Keep, or take the scenario name as a parameter of `go`. |
| Expected results only in prose, compared by eye. | Keep one expected `(S,P)` pair per frame in `scenes/` so a diff can check them. |
| 10 frames per scenario. | 20 frames (course requirement). |

## 12. Possible extensions (out of scope for the 10 rules)

* Vehicle-based rules: double parking, stopping in front of a driveway/gate, bus-only lane.
* Fire hydrant, taxi stand, disabled-person bay.
* Using the stopping duration as an input fact (`(request stopping 3min)`).
* Persistent beliefs across frames (`bel_type fluent`): "a ban seen 1 s ago and not yet passed".
* A speed-based feasibility rule (can the car actually stop before the zone?).

## 13. Contributions

To be filled in per the notes (rule *x* by student *k*, scenario *y* by student *l*). Suggested split for a
two-person team: scenarios 1–3 and rules R1–R5 for the first student, scenarios 4–6 and rules R6–R10 for the
second; documentation sections written by whoever wrote the corresponding part, measurements shared.

## 14. Deliverables

| Deliverable | Status |
|---|---|
| Scenarios and facts | to do (6 × 20 frames; §7 gives the design) |
| Rules | to do (R1–R10 + decision rules; §6) |
| Documentation (PDF, Moodle, `nume_prenume`) | to do; based on this spec |
| Deadline | before the summer holiday |

## References

1. *OUG 195/2002 privind circulația pe drumurile publice (Codul rutier)* and its application regulation — the
   sections on stopping and parking (oprirea și staționarea). Used for rules R1–R10. **To be verified and cited
   with exact articles in the final documentation.**
2. Overtaking Expert System (reference implementation in `Overtaking-Expert-System/`) — architecture, fact
   syntax, timing method.
3. CLIPS 6.x reference manual (modules, salience, `load-facts`, `time`).
4. Time-measurement technique credited in `AddMomentBelifsGetStartTime.clp`: Portik Annamaria & Stan Lavinia, CTI 2019.
