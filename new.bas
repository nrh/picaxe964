#picaxe 14m2

; constants
#ifdef simulating
symbol TAILLOOP = 6
#else
symbol TAILLOOP = 6000 ; approx 14 seconds to raise/lower tail
#endif

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
; I_TAIL_UP I_TAIL_DN State
; 0         1         Up
; 1         1         Middle
; 1         0         Down
symbol I_TAIL_UP = pinc.0    ; low if tail is up
symbol I_TAIL_DN = pinc.1    ; low if tail is down
symbol I_DASH = pinc.2       ; dash switch - goes high when pressed and tail is not
                             ; in selected position

symbol I_IGNITION = pinc.4
symbol I_VSS = c.3

; outputs
symbol O_TAIL_UP = b.2
symbol O_TAIL_DN = b.1
symbol O_WARN_LAMP = b.3

; variables
symbol manualmode = bit0     ; 1 = ignore speed, control manually
symbol initwarning = bit1    ; 1 = waiting for vss, 0 = vss received
symbol s_up = bit2
symbol s_dn = bit3
symbol s_dash = bit4
symbol pulses = b1           ; I_VSS pulse count
symbol hints_up = b2         ; count of TAIL_UP events > MPH_RAISETAIL
symbol hints_dn = b3         ; count of TAIL_DN events < MPH_LOWERTAIL
symbol tailtimer = w3        ; time spent raising/lowering tail


mainloop:
  setint or %00000100, %00000100, C ; interrupt on dash pin high
  if I_IGNITION = 0 then
    initwarning = 1 ; set initial state
    high O_WARN_LAMP
  endif
  if I_IGNITION = 0 and I_TAIL_UP = 0 then gosub lower_tail
  if I_IGNITION = 0 and I_TAIL_DN = 0 then goto power_down

  if manualmode = 1 then goto mainloop

  count c.3, COUNTPERIOD, pulses ; sample speed

  #ifdef simulating
  let pulses = 35
  #endif

  if initwarning = 1 AND pulses > MPH_LAMPOFF then
    initwarning = 0
    low O_WARN_LAMP
  endif

  if pulses >= MPH_RAISETAIL and I_TAIL_DN = 0 then
    hints_up = hints_up + 1
    if hints_up > NUM_HINTS_UP then gosub raise_tail
  elseif pulses <= MPH_LOWERTAIL and I_TAIL_UP = 0 then
    hints_dn = hints_dn + 1
    if hints_dn > NUM_HINTS_DN then gosub lower_tail
  endif

  goto mainloop

raise_tail:
  hints_up = 0
  setint or %00000000, %00000001, C
  high O_TAIL_UP
  for tailtimer = 1 to TAILLOOP
    if I_TAIL_UP = 0 then
      low O_TAIL_UP
      return
    endif
    next tailtimer

  ; failed to raise the tail
  low O_TAIL_UP
  high O_WARN_LAMP
  return

lower_tail:
  hints_dn = 0
  setint or %00000000, %00000010, C
  high O_TAIL_DN
  for tailtimer = 1 to TAILLOOP ; 14.1 seconds?
    if I_TAIL_DN = 0 then
      low O_TAIL_DN
      return
    endif
    next tailtimer

  ; failed to lower the tail
  low O_TAIL_DN
  high O_WARN_LAMP
  return

power_down:
  manualmode = 0
  initwarning = 1
  disablebod
  sleep 2
  enablebod
  goto mainloop

interrupt:
  low O_TAIL_UP
  low O_TAIL_DN
  if I_DASH = 1 then
    high O_WARN_LAMP
    pause 30
    low O_WARN_LAMP
    if I_DASH = 0 then
      return ; invalid button press
    endif
    manualmode = 1
    pause 100 ; hold dash button to disable manual mode
    if I_DASH = 1 then
      manualmode = 0
    else
      if I_TAIL_DN = 0 then
        gosub raise_tail
      elseif I_TAIL_UP = 0 then
        gosub lower_tail
      endif
     endif
  endif
  setint or %00000100, %00000100, C ; back to watching for dash
  return


