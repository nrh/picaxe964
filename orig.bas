'version 2 - 6/15/14  Spoiler can be manually extended, and retracted. 
'If retracted at speed, spoiler will extend at MPH_RAISETAIL



#picaxe 14M2       

'---CONSTANTS---
SYMBOL COUNTPERIOD = 548 'Number of ms (500=1/2sec) to count VSSIN PULSES - 548 gives estimated PULSES = actual MPH
SYMBOL NUMTRIGGERS_UP = 5 'Number of times the VSSIN must be reported as fast/slow for the tail to be powered up
                           ' every unit = .56 seconds  ; value of 10  = 5.6 seconds, 100 = 56 seconds
SYMBOL NUMTRIGGERS_DOWN = 100 'Number of times the VSSIN must be reported as fast/slow for the tail to be powered down
                           ' every unit = .56 seconds  ; value of 10  = 5.6 seconds, 100 = 56 seconds
SYMBOL MPH_RAISETAIL = 65  'MPH of spoiler extend, change this for extend speed
SYMBOL MPH_LOWERTAIL = 45   ' MPH of spoiler retract, change this for retract speed
SYMBOL MPH_COMMANDRAISE = 80 'speed that tail will be immediately raised, bypassing "numtriggers" counter
SYMBOL MPH_WARNLAMPOFF = 15  ' speed at which alarm lamp extinguishes


'---INPUTS---
SYMBOL TAILSTATE_DOWN = pinc.1 'low if tail is down
SYMBOL TAILSTATE_UP = pinc.0 'low if tail is up
SYMBOL MANUAL_BUTTON = pinc.2 'Common for Switch - goes HIGH on button push - stays low if tail is already in that position
SYMBOL IGNITION_ON = pinc.4
SYMBOL VSSIN = c.3 'Input for VSSIN signal

'---OUTPUTS---
SYMBOL SPOILER_UP = b.2 'Output for tail motor up
SYMBOL SPOILER_DOWN = b.1 'Output for tail motor down
SYMBOL WARN_LAMP = b.3 'Output for dash spoiler warning lamp, High to pull low

'---VARIABLES---
SYMBOL MANUALMODE = bit0 '1 if in manual tail up/down mode
SYMBOL INITWARNING = bit1 '0 if waiting for VSS signal, 1 if lamp has been turned off (VSS received)
SYMBOL PULSES = b1 'Holds VSSIN pulse count
SYMBOL TRIGGERS_UP = b2 'Holds count of highspeed trigger events received for tail up decision
SYMBOL TRIGGERS_DOWN = b3 'Holds count of lowspeed trigger events received for tail down decision
SYMBOL TAILTIMER = w2 'Holds count of time spent raising/lowering tail

'---------------------------------------------------------------------INIT----
'CURRENT TAIL POSITION:
'    TAILSTATE_UP         TAILSTATE_DOWN
'UP      0                      1
'MIDDLE  1                      1
'DOWN    1                      0


high WARN_LAMP ' warn lamp on

'-------------------------------------------------------------MainLoop--------
MainLoop:
if MANUAL_BUTTON = 1 then ButtonPushed 'console button pushed
if IGNITION_ON = 0 then 
   INITWARNING = 0 : endif' ignition is off, set up initial warning
 
if IGNITION_ON = 0 and TAILSTATE_UP = 0 then MoveTailDown  ' ignition is off, lower spoiler
if IGNITION_ON = 0 and TAILSTATE_UP = 1 then PowerDown  ' ignition is off, low power consumption
if MANUALMODE = 1 then MainLoop   ' spoiler is in manual mode
count c.3, COUNTPERIOD, PULSES 'sample speed signal from VSS  pin c.3
if INITWARNING = 0 and PULSES > MPH_WARNLAMPOFF then  gosub TurnOffWarnLamp 'turn off dash light on first VSS received
if PULSES >= MPH_RAISETAIL and TAILSTATE_UP = 1 then MoveTailUp
TRIGGERS_UP = 0 'speed fell below MPH_RAISETAIL - reset counter
if PULSES <= MPH_LOWERTAIL and MANUALMODE = 0 and TAILSTATE_DOWN = 1 then MoveTailDown
TRIGGERS_DOWN = 0 'speed went above MPH_LOWERTAIL - reset counter
goto MainLoop
'-------------------------------------------------------------MainLoop--------

'-------------------------------------------------------------BUTTON PUSHED---
ButtonPushed:
pause 30 'button bounce
if MANUAL_BUTTON = 0 then MainLoop  ' not a valid button push
low WARN_LAMP   ' clear warning lamp
MANUALMODE = 1 'no speed sensing up/down
if TAILSTATE_UP = 1 then MoveTailUp 'if tail is down or is in the middle (should never happen), raise it
if TAILSTATE_DOWN = 1 then MoveTailDown 'if tail is up , move it down
'MANUALMODE = 0 'otherwise, speed must be too high for lower - ignore lower command and take no action
goto MainLoop '(and do NOT enter manual mode)
'-------------------------------------------------------------BUTTON PUSHED---

'-------------------------------------------------------------LOWER TAIL------
MoveTailDown:
if TAILSTATE_DOWN = 0 then MainLoop
if MANUALMODE = 1 then skiptriggers_taildown
TRIGGERS_DOWN = TRIGGERS_DOWN + 1
if TRIGGERS_DOWN < NUMTRIGGERS_DOWN then MainLoop 'wait until we get NUMTRIGGERS number of speed readings
TRIGGERS_DOWN = 0                      'reset trigger count
skiptriggers_taildown: 
high SPOILER_DOWN
for TAILTIMER = 1 to 6000             'approx. 14.1 s
if TAILSTATE_DOWN = 0 then stoplower                              
next TAILTIMER
low SPOILER_DOWN  'timed out before spoiler is fully down
high WARN_LAMP    ' turn on warning light

stoplower:
low SPOILER_DOWN
MANUALMODE = 0      ' back to speed sensing mode, spoiler lowered
goto MainLoop
'--------------------------------------------------LOWER TAIL----------------

'--------------------------------------------------RAISE TAIL----------------
MoveTailUp:
if TAILSTATE_UP = 0 then MainLoop
if MANUALMODE = 1 then skiptriggers_tailup
if PULSES >= MPH_COMMANDRAISE then skiptriggers_tailup
TRIGGERS_UP = TRIGGERS_UP + 1
if TRIGGERS_UP < NUMTRIGGERS_UP then MainLoop 'wait until we get NUMTRIGGERS number of speed readings
skiptriggers_tailup:
TRIGGERS_UP = 0
high SPOILER_UP                      'power on to tail
for TAILTIMER = 1 to 6000            '4000= approx. 9.4 sec  6000 = 14.1 sec
if TAILSTATE_UP = 0 then stopraise
next TAILTIMER
low SPOILER_UP  'timed out before spoiler is fully up
high WARN_LAMP ' turn on warning light

stopraise:
low SPOILER_UP
goto MainLoop
'---------------------------------------------------RAISE TAIL----------------

'-----------------------------------------------TURN ON WARNING LAMP 
TurnOnWarnLamp: 
 high WARN_LAMP 
 goto MainLoop
'-----------------------------------------------TURN ON WARNING LAMP 

'-----------------------------------------------TURN OFF WARNING LAMP ON VSS--
TurnOffWarnLamp: 
 INITWARNING = 1
 low WARN_LAMP
 return
'-----------------------------------------------TURN OFF WARNING LAMP ON VSS--

'________________________________________POWER DOWN__________
PowerDown:
  MANUALMODE = 0  'off manual mode
  INITWARNING = 0  
  disablebod
  sleep 2 'this is about 4.6 seconds
  enablebod  
  goto MainLoop
'______________________________________________POWER DOWN__________


