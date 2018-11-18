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
symbol manual_mode = bit0     ; 1 = ignore speed, control manually
symbol initial_warning = bit1 ; 1 = waiting for vss, 0 = vss received
symbol manual_action = bit2   ; 1 = perform manual action in main loop
symbol lamp_state = bit3      ; lamp state
symbol pulses = b1            ; I_VSS pulse count
symbol hints_up = b2          ; count of TAIL_UP events > MPH_RAISETAIL
symbol hints_dn = b3          ; count of TAIL_DN events < MPH_LOWERTAIL
symbol lamp_count = b4        ; counter for flash_lamp
symbol tail_timer = w3        ; time spent raising/lowering tail

#macro flash_lamp(mson, msoff, repeat)
  let lamp_state = O_WARN_LAMP
  low O_WARN_LAMP
  pause 10

  for lamp_count = 1 to repeat
    high O_WARN_LAMP
    pause mson
    low O_WARN_LAMP
    pause msoff
    next lamp_count

  if lamp_state = 1 then
    high O_WARN_LAMP
  else
    low O_WARN_LAMP
  endif
#endmacro


mainloop:
  setint or %00000100, %00000100, C ; interrupt on dash pin high
  if I_IGNITION = 0 then
    initial_warning = 1
    high O_WARN_LAMP
    if I_TAIL_UP = 1 and I_TAIL_DN = 1 then gosub reset_tail
    if I_TAIL_UP = 0 then gosub lower_tail
    if I_TAIL_DN = 0 then goto power_down
  endif

  count c.3, COUNTPERIOD, pulses ; sample speed

  #ifdef simulating
  let pulses = 15
  #endif

  ; disable warning lamp if we have an initial speed reading
  if initial_warning = 1 AND pulses >= MPH_LAMPOFF then
    initial_warning = 0
    low O_WARN_LAMP
  endif

  ; raise regardless of manual_mode if we exceed MPH_AUTORAISE
  if pulses >= MPH_RAISETAIL and I_TAIL_DN = 0 then
    if pulses >= MPH_AUTORAISE then
      gosub raise_tail
	    goto mainloop
    endif
  endif

  ; manual_mode=1 is set in the interrupt handler for the dash switch
  ; we process manual mode here rather than in the interrupt handler
  ; because reasons
  if manual_mode = 1 then
    if manual_action = 1 then ; in a manual raise/lower action
      if I_TAIL_UP = 0 then
	      gosub lower_tail
	      manual_action = 0
      elseif I_TAIL_DN = 0 then
	      gosub raise_tail
	      manual_action = 0
      else ; intermediate state, try lowering the tail
	      gosub reset_tail
	      manual_action = 0
      endif
    endif
    goto mainloop
  endif

  ; raise regardless of manual_mode if we exceed MPH_AUTORAISE
  if pulses >= MPH_RAISETAIL and I_TAIL_DN = 0 then
    if pulses >= MPH_AUTORAISE then
      gosub raise_tail
	    goto mainloop
    endif
  endif

  ; we use 'hints' up and down - we need to hint several times to
  ; trigger a tail action to avoid thrash
  ; hints are reset in the subs
  if pulses >= MPH_RAISETAIL and I_TAIL_DN = 0 then
    hints_up = hints_up + 1
    if hints_up > NUM_HINTS_UP then
      gosub raise_tail
    endif
  elseif pulses <= MPH_LOWERTAIL and I_TAIL_UP = 0 then
    hints_dn = hints_dn + 1
    if hints_dn > NUM_HINTS_DN then
      gosub lower_tail
    endif
  endif

  goto mainloop

raise_tail:
  hints_up = 0
  setint or %00000000, %00000001, C
  high O_TAIL_UP
  for tail_timer = 1 to TAILLOOP
    if I_TAIL_UP = 0 then
      low O_TAIL_UP
      return
    endif
    next tail_timer

  ; failed to raise the tail
  low O_TAIL_UP
  high O_WARN_LAMP
  flash_lamp(20, 20, 10)
  return

lower_tail:
  hints_dn = 0
  setint or %00000000, %00000010, C
  high O_TAIL_DN
  for tail_timer = 1 to TAILLOOP ; 14.1 seconds?
    if I_TAIL_DN = 0 then
      low O_TAIL_DN
      return
    endif
    next tail_timer

  ; failed to lower the tail
  low O_TAIL_DN
  flash_lamp(50, 10, 3)
  high O_WARN_LAMP
  return

reset_tail:
  return

power_down:
  manual_mode = 0
  initial_warning = 1
  disablebod
  sleep 2
  enablebod
  goto mainloop

interrupt:
  low O_TAIL_UP
  low O_TAIL_DN
  if I_DASH = 1 then
    ; we flash the lamp for ~40ms
    ; if the dash is still switched we recognize the action
    flash_lamp(30, 10, 1)
    if I_DASH = 0 then
      return ; didn't hold it long enough, invalid button press
    endif

    ; 40ms has passed - now we're doing manual stuff
    manual_mode = 1
    manual_action = 1
    pause 500
    flash_lamp(30, 10, 3)
    ; if we are *still* holding the dash button after this second flash
    ; we cancel manual mode and return to normal
    if I_DASH = 1 then
      manual_mode = 0
	    manual_action = 0
    endif
  endif
  setint or %00000100, %00000100, C ; back to watching for dash
  return



