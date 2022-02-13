; Archivo: LAB03PDM_am.s
; Dispositivo: PIC16F887
; Autor: ALFREDO MELENDEZ
; Compilador: pic-as (v2.32), MPLABX v5.50
;-------------------------------------------
; Programa: Botones y Timer0, display 7 segmentos
; Hardware: LEDs, botones, resistencias, pic16F887, display de 7 segmentos
;-------------------------------------------
; Creado: 06 FEB, 2022
; Última modificación: 12 FEB, 2022
    

PROCESSOR 16F887
    

; PIC16F887 Configuration Bit Settings

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT   ; Oscillator Selection bits (INTOSC oscillator: CLKOUT function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

#include <xc.inc>

PSECT resVect, class=CODE, abs, delta=2
ORG 00h	
  
;reset vector
resetVec:
    PAGESEL main
    GOTO    main
;VARIABLES
PSECT udata_bank0
    FLG: DS 1
    CNTR: DS 1
    
PSECT code, delta=2, abs
ORG 100h
 
 
;Configuration
main:
    ;ANSEL
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH
    ;TRIS
    BANKSEL TRISA
    BSF	    TRISA,0 ;input 
    BSF	    TRISA,1 ;input
    BCF	    TRISA,3 ;output
    CLRF    TRISB   ;LIMPIAMOS TRIS B,C,D PARA USARLOS COMO OUTPUT
    CLRF    TRISC
    CLRF    TRISD
    ;PORTS
    BANKSEL PORTA   ;ELEGIMOS BANCO DE PUERTO A
    CLRF    PORTA   ;LIMPIAMOS PUERTOS
    CLRF    PORTB
    CLRF    PORTC
    CLRF    PORTD
    CLRWDT ;LIMPIAMOS WATCHDOG TIMER
    BANKSEL OPTION_REG
    MOVLW   11010000B ;precarga vals T0CS
    ANDWF   OPTION_REG, W
    IORLW   00000100B ;PRESC 1:32
    MOVWF   OPTION_REG
    BANKSEL OSCCON ;FOSC A 8MHz con 111 por BSF y osc interno con scs
    BSF	    OSCCON, 4 
    BSF	    OSCCON, 5
    BSF	    OSCCON, 6
    BSF	    SCS
    CALL tmr ;
    
    
LOOP:
    ;Botones incrementador y decrementador de contador puerto B
    BTFSC   PORTA, 0 
    CALL    AR1 ;antirebote pb1
    BTFSS   PORTA, 0
    CALL    incremento
    BTFSC   PORTA, 1
    CALL    AR2 ;antirebote pb2
    BTFSS   PORTA,1
    CALL    decremento
    CALL    tabla
    MOVWF   PORTD, F
    
    ; temporizador
    
    BTFSS INTCON, 2
    GOTO  $-1
    CALL  tmr
    MOVLW 250
    SUBWF CNTR,0
    BTFSC STATUS,2
    CALL  temporizer
    CALL  counter_UP
    ;Bit indicador RA3
    MOVF    PORTB, W ;El valor de B pasado a W al usar subwf ocurre que al
    SUBWF   PORTC, 0 ;ser igual C y B en bits si la resta da 0 el status se chequea
    BTFSC   STATUS, 2 ;como tenemos btfsc se salta la linea y vamos a la subrutina
    CALL    OF	      ; del OF de overflow que indica que se supero la cantidad
    GOTO    LOOP      ; de bits puestos por el contador de botones
 
//SUBRUTINAS
 
OF:
    MOVLW   0X08
    XORWF   PORTA, F
    CLRF    PORTB
    BCF	    STATUS, 2
    RETURN
tmr:;Timer que reinicia el loop y activa la bandera de INTCON propia de tmr0
    BANKSEL TMR0
    MOVLW   255 ;valor precarga calculado
    MOVF    TMR0
    BCF	    INTCON, 2
    RETURN
temporizer: ;TEMPORIZADOR PUERTO B DE ACUERDO AL C
    INCF    PORTB, F
    BTFSC   PORTB, 4
    CLRF    PORTB
    BCF	    STATUS, 2
     
counter_UP:
    INCF    CNTR
    BCF	    INTCON, 2	
    RETURN
 
 ;Tabla 7segment
 ; con esta tabla hacemos la conversion de lo que se encuentra en el puerto C
 ; y se representa en hexadecimal en el puerto D con el 7 segment
 tabla:
    CLRF    PCLATH
    BSF	    PCLATH, 0 ; COLOCAMOS PCLATH EN 01
    MOVWF   PORTC, W
    ;ANDLW   0X0f
    ADDWF   PCL, F	;PC = PCLATH + PCL + W
    retlw   00111111B; 0
    retlw   00000110B; 1
    retlw   01011011B; 2
    retlw   01001111B; 3
    retlw   01100110B; 4
    retlw   01101101B; 5
    retlw   01111101B; 6
    retlw   00000111B; 7
    retlw   01111111B; 8
    retlw   01101111B; 9
    retlw   01110111B; a
    retlw   01111100B; b
    retlw   00111001B; c
    retlw   01011110B; d
    retlw   01111001B; e
    retlw   01110001B; f
    
 //PUSHBUTTONS DE INCREMENTO Y DECREMENTO
   
   ;PB1
incremento:
    BTFSS FLG, 0 ;Si el pb esta presionado se salta el return
    RETURN
    INCF    PORTC, F ;incrementea 1 valor en C
    BTFSC   PORTC, 4
    CLRF    PORTC ;si el puerto C en el bit 4 es 1 se limpia el puerto
    CLRF    FLG ; se vuelve a limpiar la bandera
    RETURN
    ;PB2
decremento:
    BTFSS   FLG,1   ;si el pb no esta presionado salta el return
    RETURN
    DECF    PORTC, F ;decrementa 1 valor en C
    MOVLW   0X0F
    BTFSC   PORTC, 4 ;si el puerto C en el bit 4 es 1 se limpia el puerto
    MOVWF   PORTC
    CLRF    FLG
    RETURN
 
//ANTIRREBOTES DE PB1 Y PB2 respectivamente
AR1:
    BSF FLG, 0
    RETURN    
AR2:
    BSF FLG,1
    RETURN

END