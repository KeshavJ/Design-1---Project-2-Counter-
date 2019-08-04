;*******************************************************************************								    	            
;    Student Name	    : Keshav Jeewanlall			            
;    Student Number	    : 213508238	                                                
;    Date		    : 22 / 08 / 2017                                    
;    Description	    : Count up & down (from 0 to 99) using two   
;			      push button switches & two SSDs
;    
; Counting up is done using a push button as an external interrupt on pin RA2.
; Counting down is done using a push button that is being polled via pin RA5.
;*******************************************************************************

    List p=16f690			
#include <p16F690.inc>		
errorlevel  -302		
    __CONFIG   _CP_OFF & _CPD_OFF & _BOR_OFF & _MCLRE_ON & _WDT_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT & _FCMEN_OFF & _IESO_OFF 

;************************VARIABLE DEFINITIONS & VECTORS*************************         
 UDATA
tempW	          RES 1	    ;temporarily stores value in W register when 
		            ;interrupt occurs
count		  RES 1	    ;stores the count of the button press
tens		  RES 1	    ;stores tens digit
units		  RES 1	    ;stores units digit 
temp	          RES 1	    
temp2             RES 1	    

EXTERN Binary_To_BCD	    ;library to convert binary to BCD
	     
RESET ORG 0x00		    ;Reset vector, PIC starts here on power up and reset
GOTO Setup
 
ORG 0x04		    ;The PIC will come here on an interrupt
			    ;This is our interrupt routine that we want 
			    ;the PIC to do when it receives an interrupt
			    
;*******************************INTERRUPT ROUTINE**********************************		    
Count_Up_Interrupt
    MOVWF tempW	    
    CALL Switch_Debounce    ;call switch debouncing module	    
    INCF count		    ;increase count on button press
    MOVLW 0x1C		    ;adds 28 to count
    ADDWF count,0	    ;if count is 128 or greater, bit 7 will set
    MOVWF temp		    
    BTFSC temp,7	    ;if bit 7 is clear, number is under 100
    CLRF count		    ;reset the number count after 99
    BCF INTCON,1	    ;enable the interrupt again
    MOVFW tempW		    ;restore W register value from before the interrupt
    RETFIE		    ;This tells the PIC that the interrupt routine 
			    ;has finished and the PC will point back to the 
			    ;main program

;**************************SETUP OF PIC16F690 PORTS*****************************
Setup 
			;Select Bank 1
    BSF STATUS,5	
    BCF STATUS,6
    
    BSF INTCON,7	;enable Global Interrupt
    BSF INTCON,4	;enable External Interrupt
    CLRF TRISC		;set PORTC as output for ssds 
    CLRF TRISA
    BSF TRISA,2		;set pin RA2 as input for count up button
    BSF TRISA,5		;set pin RA5 as input for count down button 
    BCF OPTION_REG, 6	;setting bit 6 of OPTION_REG ensures that the interrupt
			;occurs on the falling edge (Button Press)
    
			;select Bank 2
    BCF STATUS,5
    BSF STATUS,6
    
    CLRF ANSEL		;enable digital I/O on ports
    
			;select Bank 0
    BCF STATUS,6
    
			;clear registers
    CLRF count	
    CLRF tempW
    CLRF temp
    CLRF temp2
    CLRF tens
    CLRF units
    
    GOTO Display_loop	;go to the main loop
    
Code
 
;***************************CODE FOR DISPLAYING ON SSDs*************************
    
Display_loop
   CALL Display
   BTFSS PORTA,5	  ;checks if counting down button is pressed
   CALL Counting_Down	  ;calls subroutine if it is pressed
GOTO Display_loop

Display
    CALL Convert_to_BCD	  ;subroutine to convert count to BCD
    BCF PORTA,4		  ;clear pin RA4 to disable units SSD
    CALL SSD_Table	  ;gets code for displaying the number (Tens)
    ADDLW 0x80		  ;setting the MSB (Bit 7) will enable the Tens SSD
    MOVWF PORTC		  ;display Tens value
  
    BSF PORTA,4		  ;Set pin RA4 to enable units SSD
    MOVFW units		    
    CALL SSD_Table	  ;gets code for displaying the number (Units)
    MOVWF PORTC		  ;displays units value
    
    CALL Multiplexing_Delay  ;delay for multiplexing SSDs
    
    RETURN
    
Convert_to_BCD		  ;converts count to BCD
    MOVFW count
    Call Binary_To_BCD	  ;uses library subroutine to get BCD value of number
    MOVWF tens
    ANDLW 0x0F		  ;b'00001111 , clears upper nibble of BCD number
    MOVWF units		  ;stores the value as the units
    SWAPF tens,1	  ;swaps the nibbles of the BCD number
    MOVFW tens		  
    ANDLW 0x0F		   ;b'00001111, clears the high nibble to get tens value
    MOVWF tens		   ;stores value in tens register
    RETURN
  
 SSD_Table
			  ;These HEX values are required because common anode SSDs
			  ;are being used
    ADDWF PCL,1
    RETLW 0x40		  ;displays number 0 on SSD
    RETLW 0x79		  ;displays number 1 on SSD    
    RETLW 0x24		  ;displays number 2 on SSD
    RETLW 0x30		  ;displays number 3 on SSD
    RETLW 0x19		  ;displays number 4 on SSD
    RETLW 0x12		  ;displays number 5 on SSD
    RETLW 0x02		  ;displays number 6 on SSD
    RETLW 0x78		  ;displays number 7 on SSD
    RETLW 0x00		  ;displays number 8 on SSD
    RETLW 0x10		  ;displays number 9 on SSD
 
 Counting_Down		  ;subroutine used for counting down
    CALL Switch_Debounce    
    DECF count		  ;Decreases the number count by 1
    BTFSS count,7	  ;If -1 occurs, bit 7 will be set, reset count to 99
    GOTO No_Reset	  ;else skip
    MOVLW 0x63
    MOVWF count
  No_Reset
    CALL Display	  ;ensures that count is decreased on button press
  Constant_Display_loop	  ;waits till button gets released to avoid changing
			  ;count when button is held down
    BTFSC PORTA,5	  ;if switch is released
    RETURN		  ;exit the loop
    GOTO Constant_Display_loop ;else wait until switch is released
  
Multiplexing_Delay	  ;delay for multiplexing SSDs to allow for 
			  ;equal brightness
    MOVLW 0x32
    MOVWF temp
  Multiplex_loop
    DECFSZ temp
    GOTO Multiplex_loop
    RETURN
    
;****************************SWITCH DEBOUNCING CODE*****************************
Switch_Debounce
    MOVLW 0xC8		    ;Switch Debouncing
    MOVWF temp
    MOVWF temp2
Debounce_loop		    
    DECFSZ temp2
    GOTO Debounce_loop
    DECFSZ temp
    GOTO Debounce_loop	    ;End of switch debouncing
    RETURN
    
End

;**********************************REFERENCES***********************************
; Krishundutt, N. (2016). Project 2 - Version 2- 214551467.
    