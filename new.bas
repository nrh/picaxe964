#picaxe 14m2

; constants
symbol COUNTPERIOD = 548     ; number of ms to count vss_in pulses
                             ; 548 gives means vss_in ~= actual mph
symbol NUM_HINTS_UP = 5      ; number of times vss_in must be reported as fast/slow for the
symbol NUM_HINTS_DN = 5      ; tail to be triggered up/down
                             ; 1 unit = .56sec
                             ; 5 = 2.8sec
symbol MPH_RAISETAIL = 65
symbol MPH_LOWERTAIL = 45
symbol MPH_AUTORAISE = 80    ; speed at which tail will be immediately raised
                             ; bypassing NUM_HINTS_UP
symbol MPH_LAMPOFF = 15


; tail position:
; I_TAIL_DN I_TAIL_UP State
; 0         1         Up
; 1         1         Middle
; 1         0         Down
symbol I_TAIL_DN = pinc.0    ; low if tail is up
symbol I_TAIL_UP = pinc.1    ; low if tail is down
symbol I_DASH = pinc.2  ; dash switch - goes high when pressed and tail is not
                             ; in selected position
symbol I_IGNITION = pinc.4
symbol I_VSS = c.3

; outputs
symbol O_TAIL_UP = b.2
symbol O_TAIL_DN = b.1
symbol O_WARN_LAMP = b.3

; variables
symbol manualmode = bit0     ; 1 = ignore speed, control manually
symbol initwarning = bit1    ; 0 = waiting for vss, 1 = vss received
symbol warn_state = bit3
symbol pulses = b1           ; I_VSS pulse count
symbol hints_up = b2         ; count of TAIL_UP events > MPH_RAISETAIL
symbol hints_dn = b3         ; count of TAIL_DN events < MPH_LOWERTAIL
symbol tailtimer = w2        ; time spent raising/lowering tail

mainloop:
  if I_DASH = 1 then goto button_pushed
  if I_IGNITION = 0 then
    initwarning = 0 ; set initial state
  endif
  if I_IGNITION = 0 and I_TAIL_DN = 0 then goto lower_tail
  if I_IGNITION = 0 and I_TAIL_UP = 0 then goto power_down
  if manualmode = 1 then goto mainloop

  count c.3, COUNTPERIOD, pulses ; sample speed

  if initwarning = 0 and pulses > MPH_LAMPOFF then
    initwarning = 1
    low O_WARN_LAMP
  endif

  if pulses >= MPH_RAISETAIL and I_TAIL_UP = 0 then goto hint_raise_tail
  ; if we reach here rather than jumping to mainloop, speed fell below MPH_RAISETAIL
  hints_up = 0

  if pulses <= MPH_LOWERTAIL and I_TAIL_DN = 0 then goto hint_lower_tail
  ; if we reach here rather than jumping to mainloop, speed went above MPH_LOWERTAIL
  hints_dn = 0

  goto mainloop

button_pushed:
  pause 30 ; 30ms
  if I_DASH = 0 then goto mainloop ; invalid button press
  if manualmode != 1 then
    manualmode = 1
    gosub flash_warning
    if I_TAIL_DN = 0 then goto raise_tail
    if I_TAIL_UP = 0 then goto lower_tail
  endif

  manualmode = 0
  goto mainloop

hint_lower_tail:
  if I_TAIL_UP = 0 then goto mainloop
  hints_dn = hints_dn + 1
  if hints_dn > NUM_HINTS_DN then goto lower_tail
  goto mainloop

lower_tail:
  hints_dn = 0
  high O_TAIL_DN
  for tailtimer = 1 to 6000 ; 14.1 seconds?
    if I_TAIL_UP = 0 then
      low O_TAIL_DN
      manualmode = 0
      goto mainloop
    endif
    next tailtimer

  ; failed to lower the tail
  low O_TAIL_DN
  high O_WARN_LAMP
  goto mainloop

hint_raise_tail:
  if I_TAIL_DN = 0 then goto mainloop
  hints_up = hints_up + 1
  if hints_up > NUM_HINTS_UP then goto raise_tail
  goto mainloop

raise_tail:
  hints_up = 0
  high O_TAIL_UP
  for tailtimer = 1 to 6000
    if I_TAIL_DN = 0 then
      low O_TAIL_UP
      goto mainloop
    endif
    next tailtimer

  ; failed to raise the tail
  low O_TAIL_UP
  high O_WARN_LAMP
  goto mainloop

power_down:
  manualmode = 0
  initwarning = 0
  disablebod
  sleep 2
  enablebod
  goto mainloop

flash_warning:
  let warn_state = O_WARN_LAMP
  high O_WARN_LAMP
  pause 150
  low O_WARN_LAMP
  pause 100
  high O_WARN_LAMP
  pause 150
  low O_WARN_LAMP
  pause 100
  high O_WARN_LAMP
  pause 150
  if warn_state = 1 then
    high O_WARN_LAMP
  else
    low O_WARN_LAMP
  endif
  return










