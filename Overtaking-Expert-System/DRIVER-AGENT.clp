;;----------------------------------
;;
;;  Transformarea articolelor din codul rutier cu privire la validarea depasirii in reguli CLIPS
;;
;;----------------------------------

(defrule AGENT::vehicul_in_spate
    (timp (valoare ?t))
    ?f<-(ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval allowed))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname isa) (bel_pval vehicle))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname has_type) (bel_pval car))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname rel_pos) (bel_pval left_back|back))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname blink) (bel_pval left))
=>
    (retract ?f)
    (assert (ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval prohibited)))
)

(defrule AGENT::vehicul_in_fata
    (timp (valoare ?t))
    ?f<-(ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval allowed))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname isa) (bel_pval vehicle))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname rel_pos) (bel_pval left_front|front))
    ; (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname blink) (bel_pval left))
    ; (not (ag_bel (bel_type moment) (bel_pobj ?obj2) (bel_pname isa) (bel_pval road_attribute)))
    (not (ag_bel (bel_type moment) (bel_pobj ?obj2) (bel_pname has_type) (bel_pval free_space)))
=>
    (retract ?f)
    (assert (ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval prohibited)))
)

(defrule AGENT::coloana
    (timp (valoare ?t))
    ?f<-(ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval allowed))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname isa) (bel_pval vehicle))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname rel_pos) (bel_pval front))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname has_type) (bel_pval column))
=>
    (retract ?f)
    (assert (ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval prohibited)))
)

(defrule AGENT::tramvai_in_statie_fara_refugiu
    (timp (valoare ?t))
    ?f<-(ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval allowed))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname isa) (bel_pval vehicle))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname has_type) (bel_pval tram))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname rel_dist) (bel_pval ?dist))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname rel_pos) (bel_pval left_front|front))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname blink) (bel_pval right))
    (ag_bel (bel_type moment) (bel_pobj ?obj2) (bel_pname isa) (bel_pval road_elem))
    (ag_bel (bel_type moment) (bel_pobj ?obj2) (bel_pname has_type) (bel_pval tram_station_without_shelter))
    (ag_bel (bel_type moment) (bel_pobj ?obj2) (bel_pname rel_dist) (bel_pval ?dist))
    (ag_bel (bel_type moment) (bel_pobj ?obj2) (bel_pname rel_pos) (bel_pval front|left_front))
=>
    (retract ?f)
    (assert (ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval prohibited)))
)

(defrule AGENT::intersectie_nedirijata
    (timp (valoare ?t))
    ?f<-(ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval allowed))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname isa) (bel_pval interection))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname rel_pos) (bel_pval front))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname is_road) (bel_pval left|right))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname is_driven) (bel_pval false))
=>
    (retract ?f)
    (assert (ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval prohibited)))
)

(defrule AGENT::vizibilitate_redusa
    (timp (valoare ?t))
    ?f<-(ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval allowed))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname isa) (bel_pval road_nature))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname has_visibility) (bel_pval ?vis))
    (test(< ?vis 5000))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname has_type) (bel_pval curve|slope|fog))
=>
    (retract ?f)
    (assert (ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval prohibited)))
)

(defrule AGENT::pasaje
    (timp (valoare ?t))
    ?f<-(ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval allowed))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname isa) (bel_pval road_nature))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname has_type) (bel_pval bridge|under_bridge|tunnel))
    (ag_bel (bel_type moment) (bel_pobj ?obj2) (bel_pname isa) (bel_pval road_attribute))
    (not (ag_bel (bel_type moment) (bel_pobj ?obj2) (bel_pname has_type) (bel_pval free_space)))
=>
    (retract ?f)
    (assert (ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval prohibited)))
)

(defrule AGENT::trecere_de_pietoni
    (timp (valoare ?t))
    ?f<-(ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval allowed))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname isa) (bel_pval road_elem))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname has_type) (bel_pval crosswalk))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname rel_pos) (bel_pval front))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname rel_dist) (bel_pval ?dist))
    (test(< ?dist 1000))
=>
    (retract ?f)
    (assert (ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval prohibited)))
)

(defrule AGENT::trecere_la_nivel_cu_cale_ferata
    (timp (valoare ?t))
    ?f<-(ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval allowed))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname isa) (bel_pval road_elem))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname has_type) (bel_pval railway_level_crossing))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname rel_pos) (bel_pval front))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname rel_dist) (bel_pval ?dist))
    (test(< ?dist 5000))
=>
    (retract ?f)
    (assert (ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval prohibited)))
)

(defrule AGENT::depasirea_interzisa_sau_banda_continua_denivelat
    (timp (valoare ?t))
    ?f<-(ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval allowed))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname isa) (bel_pval road_attribute))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname has_type) (bel_pval bumpy_road|overtaking_prohibited|continuous_strip|discontinuous_continuous_strip))
=>
    (retract ?f)
    (assert (ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval prohibited)))
)

(defrule AGENT::verificare_restrictii_in_fata
    (timp (valoare ?t))
    ?f<-(ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval allowed))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname isa) (bel_pval road_attribute))
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname rel_dist) (bel_pval ?dist))    
    (ag_bel (bel_type moment) (bel_pobj ?obj) (bel_pname has_type) (bel_pval bumpy|overtaking_prohibited|continuous_strip|discontinuous_continuous_strip))
    (test(< ?dist 15000))
=>
    (retract ?f)
    (assert (ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval prohibited)))
)

;
; Mandatory rule
;

(defrule AGENT::initCycle-overtaking
    (declare (salience 89))
    (timp (valoare ?)) ;make sure it fires each cycle
=>
    (if (eq ?*ag-in-debug* TRUE) then (printout t "    <D>initCycle-overtaking allowed by default " crlf))
    (assert (ag_bel (bel_type moment) (bel_pname overtaking-maneuver) (bel_pval allowed)))
    ;(facts AGENT)
)
