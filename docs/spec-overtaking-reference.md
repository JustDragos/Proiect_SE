# Specification — Overtaking Expert System

> Course project, Expert Systems (Sisteme Expert), year IV.
> Reference implementation: the code in `Overtaking-Expert-System/`.
>
> This document specifies what the project must do (the course requirements from the lecture notes) and
> documents what the existing implementation actually does. Section 11 lists gaps between the two.

---

## 1. Purpose

A rule-based **driving agent** for an autonomous car, written in **CLIPS**. At every time frame it receives
the facts produced by the car's sensors and answers one question:

> *Is the overtaking maneuver currently allowed or prohibited?*

The decision is based on the Romanian traffic code (overtaking chapter, ref. [1]). The agent is
reactive: it keeps no memory between frames — each frame is decided on its own facts.

## 2. Course requirements (from the lecture notes)

### 2.1 Data model

| Requirement | Notes |
|---|---|
| Input is a series of **frames** (clips). A frame is one instant in time holding a set of **facts** (sensor readings). | A frame is a set of `ag_percept` facts. |
| Fact shape is *object – property – value*. | e.g. "object 1 is a car", "object 1 relative position left", "distance from object 2", "object has color", "left mirror". |
| Each **folder** is one **test scenario** and holds *k* frames. | `percepts/sceneN/t1.clp … tk.clp`. |
| **3 scenarios per student, 20–30 frames per scenario.** | The repo has 6 scenarios (2 authors × 3) of **10** frames each — see §11. |
| After the first frame is processed, it is removed from working memory; intermediate data may be kept. | Percepts of frame *t* are retracted before frame *t+1* is loaded. |
| Sensors have a **transfer time** (e.g. front sensor 2 ms, rear sensor 10 ms); the car's **speed** is one sensor reading per frame and should be taken into account. | Sensor timings are documented (§4); speed is **not yet** modelled (§11). |

### 2.2 Rules

* Model the traffic rules: *given the frame(s), is the maneuver permitted?*
* Example conditions: detect a discontinuous lane line; a car is on my left.
* Simplifying assumption allowed: **the maneuver is permitted by default** (a plain `if`-style rule base)
  and rules only veto it.
* A `DRIVER-AGENT` file contains the rules and outputs *maneuver allowed / not allowed*.

### 2.3 Performance

* **Measure the response time**: run in debug mode, record the decision time per frame, and take the
  **average decision time** over many runs to judge whether the maneuver can be executed in time.

### 2.4 Documentation (the deliverable)

* Which sensors are needed (e.g. radar, GPS) and each sensor's response time.
* **Syntax of the facts** and how to interpret the data.
* **Individual contributions** (rule *x* by student *k*, scenario *y* by student *l*).
* External references / bibliography, with where each source was used.

### 2.5 Grading order

1. Model the scenarios → model the facts.
2. Model the rules.
3. Documentation.

The project is run and checked for correct inference. **Submit on Moodle: documentation only**, filename
`nume_prenume`, **before the summer holiday**.

## 3. System architecture

CLIPS program split into three modules that take turns through a *focus* sequence.

```
            ┌────────────────────────── MAIN ──────────────────────────┐
            │  secventa (PERCEPT-MANAGER AGENT)  — rotates, asserts tic │
            └───────────────┬───────────────────────────┬──────────────┘
                   focus     │                           │ focus
                             ▼                           ▼
              ┌──────────────────────────┐   ┌───────────────────────────────┐
              │     PERCEPT-MANAGER      │   │             AGENT             │
              │ delete old ag_percept    │   │ percepts → moment beliefs     │
              │ timp := timp + 1         │──▶│ default: overtaking allowed   │
              │ load-facts t<timp>.clp   │   │ veto rules → prohibited       │
              └──────────────────────────┘   │ print decision + decision time│
                                             │ delete moment beliefs         │
                                             └───────────────────────────────┘
```

### 3.1 Modules

| Module | Role | Exports / imports |
|---|---|---|
| `MAIN` | Cycles the focus between the other modules via the `secventa` fact. Asserts a `tic` each time it hands control to `PERCEPT-MANAGER`. | exports `tic` |
| `PERCEPT-MANAGER` | Simulates the sensors: clears the previous frame, increments time, loads the next frame file. | imports `tic`; exports `timp`, `ag_percept` |
| `AGENT` | Driver agent: reasoning, decision output, housekeeping, timing. | imports `timp`, `ag_percept` |

### 3.2 One cycle (one frame)

1. `MAIN::succesiune` rotates `secventa`, asserts `tic`, focuses `PERCEPT-MANAGER`.
2. `PERCEPT-MANAGER::hk-ag_percepts` retracts every `ag_percept` of the previous frame (only while `tic` exists).
3. `PERCEPT-MANAGER::advance-time-percepts` (salience −95): `timp ← timp+1`, retracts `tic`, and does
   `(load-facts "./percepts/sceneN/t<timp>.clp")`.
4. `MAIN` focuses `AGENT`, which runs in this priority order:

   | Salience | Rule | Effect |
   |---|---|---|
   | 96 | `time_start` | asserts `(tstart (time))` |
   | 93 | `percepts_into_beliefs` | copies each `ag_percept` into an `ag_bel` of type `moment` |
   | 89 | `initCycle-overtaking` | asserts `overtaking-maneuver = allowed` (the default) |
   | 0 | veto rules (§6) | retract *allowed*, assert *prohibited* |
   | −50 | `tell` | prints `AGENT overtaking-maneuver <allowed\|prohibited>` and retracts the belief |
   | −85 | `hk-eliminate-momentan-current-bel` | retracts all remaining `moment` beliefs |
   | −92 | `time_end` | prints the decision time (if `?*ag-measure-time*` is `TRUE`) |

### 3.3 Termination

The agent never stops on its own; `(run ?*totalNrRules*)` caps the number of rule firings. This cap is a
hand-counted number per scenario (see §9). After the last frame, `load-facts` is called on a file that does
not exist, so the agent would keep cycling with no percepts until the firing budget runs out.

## 4. Sensors

Time figures are those given in `Documentatie_Sisteme_Expert.pdf` (pairing of rows to timings was recovered
from text extraction order). A frame is extracted from the sensors **every 200 ms**; a scenario records
**2 s** → 10 frames.

| Sensor | Purpose | Response time |
|---|---|---|
| Rangefinder laser / LiDAR | distance to an object, front/rear | < 5 ms |
| Ultrasonic sensor in mirrors | lane assist, blind-spot handling | < 1 ms |
| Stereo-vision camera (front and rear) | max road depth → visibility | 10–30 ms |
| PPP or RTK positioning | geographic position, centimetre precision | < 5 ms |
| Advanced map system | road restrictions from position | 5 ms + 150 ms |
| Gyroscope | road inclination | < 1 ms |
| Front camera + deep-learning classifier | classifies recognised entities into fixed categories | 16 ms + 150 ms |

Technical assumptions:

* If the rangefinder reports maximum distance, there is nothing nearby.
* Buffers signal entry into a tunnel / under a bridge.
* The `percept_pobj` value is an arbitrary object name (`elem1`, `elem2`, …).
* Detected **free space** is automatically ≥ 3.5 m on the adjacent lanes and ahead.
* Distances and visibility are in **centimetres**.
* Tram at a station without shelter: the tram's **right-turn signal takes priority**. While it blinks the tram
  is considered to be loading, overtaking is prohibited; when the signal stops, doors are assumed closed and no
  pedestrians on the roadway.

## 5. Fact syntax

### 5.1 Templates

```clips
(deftemplate PERCEPT-MANAGER::ag_percept      ; produced by a sensor frame
    (slot percept_pobj)    ; object id (elem1, ev, …)
    (slot percept_pname)   ; property
    (slot percept_pval))   ; value

(deftemplate AGENT::ag_bel                    ; agent's internal belief
    (slot bel_type)        ; fluent | moment   (only `moment` is used)
    (slot bel_pname)       ; property
    (slot bel_pval)        ; value
    (slot bel_pobj))       ; object id (absent for the decision itself)

(deftemplate PERCEPT-MANAGER::timp (slot valoare))   ; current frame number, starts at 0
(deftemplate MAIN::tic)                              ; "advance the clock" token
```

Control facts: `(secventa PERCEPT-MANAGER AGENT)` (initials.clp), `(ASK overtaking-maneuver)`
(maneuverValidityASK.clp — selects which maneuver `tell` reports; `right-turn-maneuver` is commented out).

### 5.2 Frame file layout

Every `tN.clp` is a flat list of `ag_percept` facts. Each frame has:

```clips
(ag_percept (percept_pobj ev)    (percept_pname isa)    (percept_pval eveniment))   ; the event (frame)
(ag_percept (percept_pobj elem1) (percept_pname partof) (percept_pval ev))          ; every element belongs to it
(ag_percept (percept_pobj elem1) (percept_pname isa)    (percept_pval vehicle))     ; its category
… further properties of elem1 …
```

### 5.3 Properties by category

**`isa vehicle`** — sensors: rangefinder + mirror ultrasonics + stereo camera + DL classifier

| `pname` | `pval` |
|---|---|
| `rel_dist` | number (cm) |
| `rel_pos` | `front`, `back`, `left`, `right`, plus compound `left_front`, `left_back`, `right_front` |
| `blink` | `left` \| `right` — side of the other vehicle's turn signal |
| `has_type` | `car`, `tram`, `column` (convoy), `bicycle`, `motorcycle`, `animal_traction`; documented but unused: `moped`, `bus` |

**`isa road_elem`** — sensors: stereo camera + DL classifier

| `pname` | `pval` |
|---|---|
| `rel_dist`, `rel_pos` | as above |
| `has_type` | `crosswalk`, `tram_station`, `tram_station_without_shelter`, `railway_level_crossing`; documented: `bus_station` |

**`isa intersection`** — sensors: stereo camera + DL classifier + maps

| `pname` | `pval` |
|---|---|
| `rel_dist`, `rel_pos` | as above |
| `is_road` | `left` \| `right` — side on which the cross road is seen |
| `is_driven` | `true` \| `false` — traffic-controlled or not |

**`isa road_nature`** — sensors: rangefinder + gyroscope + maps + stereo camera

| `pname` | `pval` |
|---|---|
| `has_visibility` | number (cm) |
| `has_type` | `curve`, `slope`, `fog`, `tunnel`, `under_bridge`; documented: `bridge` |

**`isa road_attribute`** — sensors: gyroscope + maps + DL classifier

| `pname` | `pval` |
|---|---|
| `rel_dist` | number (cm), optional |
| `has_type` | `discontinuous_strip`, `continuous_strip`, `continuous_discontinuous_strip`, `bumpy_road`, `overtaking_prohibited`, `free_space` |

Vocabulary actually present in the six scenarios: `isa` = {eveniment, vehicle, road_elem, road_nature,
road_attribute, intersection}; `rel_pos` = {front, back, left, right, right_front}; `blink` = {left, right};
`rel_dist` between 100 and 10000.

## 6. Rule base

All rules live in `AGENT` (`DRIVER-AGENT.clp`). Each has the same shape: the default belief
`overtaking-maneuver = allowed` is present **and** the pattern below matches ⇒ retract it, assert `prohibited`.

| # | Rule | Traffic-code situation | Condition on beliefs |
|---|---|---|---|
| 1 | `vehicul_in_spate` | Vehicle behind is already overtaking | vehicle, car, `rel_pos` ∈ {left_back, back}, `blink left` |
| 2 | `vehicul_in_fata` | Vehicle ahead and no room to pass | vehicle, `rel_pos` ∈ {left_front, front}, **no** `free_space` in the frame |
| 3 | `coloana` | Column / convoy ahead | vehicle, `rel_pos front`, `has_type column` |
| 4 | `tramvai_in_statie_fara_refugiu` | Tram stopped at a station without shelter | tram, front/left_front, `blink right`, plus a `tram_station_without_shelter` road_elem at the same `rel_dist`, front/left_front |
| 5 | `intersectie_nedirijata` | Uncontrolled intersection ahead | intersection, `rel_pos front`, `is_road` left/right, `is_driven false` |
| 6 | `vizibilitate_redusa` | Reduced visibility | road_nature, `has_visibility` < 5000, type ∈ {curve, slope, fog} |
| 7 | `pasaje` | Bridge / underpass / tunnel with no free space | road_nature type ∈ {bridge, under_bridge, tunnel}, **no** `free_space` |
| 8 | `trecere_de_pietoni` | Pedestrian crossing close ahead | road_elem crosswalk, front, `rel_dist` < 1000 |
| 9 | `trecere_la_nivel_cu_cale_ferata` | Railway level crossing close ahead | road_elem railway_level_crossing, front, `rel_dist` < 5000 |
| 10 | `depasirea_interzisa_sau_banda_continua_denivelat` | Prohibition sign, continuous line, uneven road | road_attribute type ∈ {bumpy_road, overtaking_prohibited, continuous_strip, discontinuous_continuous_strip} (no distance test) |
| 11 | `verificare_restrictii_in_fata` | Same attributes, looked-ahead | same road_attribute with `rel_dist` < 15000 |

Default rule: `initCycle-overtaking` (salience 89) — *allowed unless a rule above fires*.
Output of `tell`: `AGENT overtaking-maneuver allowed` / `prohibited`.

## 7. Scenarios and expected results

Each scenario is 10 frames, one decision per frame. `Y` = overtaking allowed, `N` = prohibited. The
descriptions are in `scenes/scenariul N`; the frame data in `percepts/sceneN/`.

| Scenario | Story | Expected decisions, frames 1–10 |
|---|---|---|
| 1 | Fog with low visibility → cyclist on the right → animal-drawn vehicle ahead and a car front-left → curve with low visibility | N N N N Y N Y Y N N |
| 2 | Tram ahead on the left → station without shelter → tram signals right (stops) → signal off | Y Y N N N N N Y Y Y |
| 3 | Uncontrolled intersection → car behind signals left → intersection passed → motorcycle on the right turning → hazard 100 m ahead | Y N N N Y Y Y Y N N |
| 4 | Curve → slope with low visibility → car ahead signalling left → tunnel | N N N N N N N Y Y Y |
| 5 | Convoy ahead turning right + uneven road → under a bridge → waiting convoy | N N Y N N Y N Y Y N |
| 6 | Pedestrian crossing → overtaking-prohibited sign → railway crossing → car ahead | Y N N N N Y N N N Y |

Acceptance: running the system for a scenario prints, per frame, the line
`AGENT overtaking-maneuver <value>` and the value equals the expected one above.

## 8. Performance measurement

* `?*ag-measure-time*` (headers.clp) enables the per-frame line `<M> AGENT Decision time: x sec.`
  (`time_start` at salience 96 to `time_end` at −92, via CLIPS `(time)`).
* Method (`DocuSE.ods`): 10 runs (R1–R10) per frame (T1–T10) per scenario; mean and dispersion (standard
  deviation) are computed per frame.
* Recorded result: the mean decision time per frame is roughly **2×10⁻⁵ s to 1.2×10⁻⁴ s**
  (22 µs – 121 µs), far below the 200 ms frame period and the 150 ms sensor latencies, so the decision
  is never the bottleneck. Larger scenes (2, 4, 5) cost more than the smaller ones, and later frames are
  faster (fewer facts).
* Speed-dependent timing (course note: use the speed sensor to judge whether the decision arrives in time) is
  not implemented.

## 9. How to run

Requires CLIPS 6.x. From `Overtaking-Expert-System/`:

```
CLIPS> (batch "go")
```

`go` clears the environment, loads in this order `headers.clp`, `MAIN-rules.clp`, `PERCEPT-MANAGER.clp`,
`AddMomentBelifsGetStartTime.clp`, `DRIVER-AGENT.clp`, `TellDeleteMomentBelifsGetEndTime.clp`,
`initials.clp`, `maneuverValidityASK.clp`, then `(reset)` and `(run ?*totalNrRules*)`.

To choose a scenario, edit **two** places in `headers.clp` (the others are commented out):

| Scenario | `?*perceptsDir*` | `?*totalNrRules*` |
|---|---|---|
| 1 | `./percepts/scene1/` | 370 |
| 2 | `./percepts/scene2/` | 520 |
| 3 (default) | `./percepts/scene3/` | 395 |
| 4 | `./percepts/scene4/` | 420 |
| 5 | `./percepts/scene5/` | 310 |
| 6 | `./percepts/scene6/` | 320 |

Debug switches in `headers.clp`: `?*main-in-debug*`, `?*ag-tic-in-debug*`, `?*sim-in-debug*`,
`?*percepts-in-debug*`, `?*ag-in-debug*`, `?*ag-percepts-in-debug*`, `?*ag-measure-time*`.

## 10. Repository layout

```
spec.md                                   this document
Overtaking-Expert-System/
  go                                      batch loader / entry point
  headers.clp                             modules, templates, globals, scenario switch
  MAIN-rules.clp                          module-rotation rule
  PERCEPT-MANAGER.clp                     frame loading and clock
  AddMomentBelifsGetStartTime.clp         start timer, percept → belief
  DRIVER-AGENT.clp                        the overtaking rules + default
  TellDeleteMomentBelifsGetEndTime.clp    print decision, cleanup, stop timer
  initials.clp / maneuverValidityASK.clp  initial facts
  percepts/scene1..6/t1..t10.clp          sensor frames
  scenes/scenariul 1..6                   textual scenario + expected result per frame
  Documentatie_Sisteme_Expert.pdf         submitted documentation (Romanian)
  DocuSE.ods                              timing measurements
```

## 11. Gaps and issues found in the existing implementation

Found by reading the code and data; CLIPS was not available, so nothing below was confirmed by execution.

**Requirements not met**

1. **Frame count:** 10 frames per scenario, requirement is 20–30. Total 6 scenarios satisfies the 3-per-student count.
2. **Speed sensor** is not part of the facts or the rules, and decision time is not compared against vehicle speed.
3. `bel_type fluent` and any memory across frames are unused; the agent is purely per-frame.

**Likely rule/data mismatches (rules that cannot fire, or fire on the wrong value)**

| Where | Problem |
|---|---|
| Rule 5 `intersectie_nedirijata` | matches `isa interection` (typo); percepts use `intersection` → **rule never fires**. |
| Rule 11 `verificare_restrictii_in_fata` | tests `bumpy`, data uses `bumpy_road`. |
| Rules 10 and 11 | test `discontinuous_continuous_strip`; the one data point is `continuous_discontinuous_strip` (documentation says both orders exist). |
| Percept data | the tunnel element in `scene4/t8.clp`, `t9.clp`, `t10.clp` uses `isa road-nature` (hyphen) instead of `road_nature`, so rules 6 and 7 cannot see it. Harmless today because those frames also contain `free_space` (rule 7 would not fire anyway), but it is a latent bug. |
| Rule 2 `vehicul_in_fata` | blocks on *any* vehicle `front`/`left_front`, including one far away, unless a `free_space` exists anywhere in the frame; it is not tied to distance or lane. |
| Rule 7 `pasaje` | its `road_attribute` `?obj2` is unrelated to the tunnel object. |
| Rules 4, 8, 9 | `rel_dist` thresholds (1000 / 5000 / 15000) assume centimetres; thresholds should be confirmed against the traffic code. |
| Rule 10 vs 11 | rule 11 is subsumed by rule 10 when the type matches (rule 10 has no distance bound). |

**Robustness**

* `?*totalNrRules*` is a manually counted firing budget and must be changed per scenario; a wrong value
  truncates the run or overruns past `t10.clp`.
* Scenario selection requires editing the source in two places.
* After `t10` the run is only stopped by the firing budget (`load-facts` on the missing `t11.clp` yields no percepts).
* Facts in `scenes/scenariul N` (expected results) are not machine-checked; comparison with the output is manual.

## 12. Contributions

*Per-rule and per-scenario attribution (rule x by k, scenario y by l) is not itemised and still has to be
completed.*

## 13. Deliverables and deadline

| Deliverable | Status |
|---|---|
| Scenarios and facts | done (6 scenarios × 10 frames; needs extending to 20–30) |
| Rules | done (11 rules + default); see §11 for defects |
| Documentation (PDF), uploaded to Moodle as `nume_prenume` | exists; update to reflect the final system and itemised contributions |
| Deadline | before the summer holiday |

## References

1. *Codul rutier — Capitolul 6, partea 1: Depășirea.* e-juridic.manager.ro,
   <https://e-juridic.manager.ro/codul-rutier/capitol-5/sectiune-2/subsectiune-3/> — source of the overtaking
   rules in §6.
2. CLIPS 6.x reference manual (modules, `defrule` salience, `load-facts`, `time`).
3. Time-measurement technique credited in `AddMomentBelifsGetStartTime.clp`: Portik Annamaria & Stan Lavinia, CTI 2019.
