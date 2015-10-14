#include <reg52.inc>

TEMPO_LIGA_ALERTA EQU 30
TEMPO_LUZ_ALERTA EQU 2

LCD_COMANDO  EQU 0FF10h
LCD_DADO	 EQU 0FF11h

VALOR_DEBITO EQU R7

JMP 2500H
ORG 2500H

; SETUP DO TIMER 2 (TIMER CONTARA 50MS)
MOV T2CON, #00000100b
MOV RCAP2H, #03Ch
MOV RCAP2L, #0B0h
MOV TH2, 	RCAP2H
MOV TL2, 	RCAP2L

; Habilita interrupcao gerada pelo estouro do timer 2
;SETB ET2
; Habilita interrupções no processador
SETB EA

; SETUP LCD
CALL LCD_INIT_STEP1
CALL LCD_INIT_STEP1
CALL LCD_INIT_STEP2
	
REINICIA_CANCELA:

	; LIMPA P1 (CANCELA SERA FECHADA AQUI CASO ESTEJA ABERTA)
	CALL REINICIA

	; AGUARDA ATÉ VEICULO ATIVAR O PRIMEIRO SENSOR E SALVA VALOR DA PORTA NO ACUMULADOR
	CALL ESPERA_POR_VEICULO

	; PEGA VALOR DEVIDO E COLOCA NA VARIAVEL "VALOR_DEBITO"
	CALL PEGA_VALOR_DEBITO

	; AGUARDA PELO PAGAMENTO DO DEBITO
	CALL AGUARDA_PAGAMENTO
	
	CALL ABRE_CANCELA

	CALL AGUARDA_PASSAGEM_VEICULO

	;MOV R0, #4 ; PARAMETRO PARA A FUNCAO
	CALL AGUARDA_N_SEGUNDOS

JMP REINICIA_CANCELA

JMP $

; FUNCOES

;------------------------------------------------------
; RESETA CANCELA PAR AO ESTADO INICIAL
REINICIA:
	MOV VALOR_DEBITO, #0
	;MOV P1, #0 ; Utilizar somente no simulador
	CLR P1.6
	CLR P1.7
	CLR P3.2
	CLR P3.3
	CLR P3.5
	CALL LCD_LIMPA_TELA
	MOV DPTR, #MSG_AGUARDANDO_VEICULO
	CALL LCD_ENVIA_FRASE
RET

;------------------------------------------------------
; AGUARDA ATE O VEICULO CHEGAR NO S1
ESPERA_POR_VEICULO: 
	EPV_LOOP:
	JNB P1.0, EPV_LOOP
	MOV A, P1
RET

;------------------------------------------------------
; COM BASE NO VALOR DO ACUMULADOR DETERMINA VALOR DO DEBITO PARA O VEICULO (GUARDA RESULTADO NA VARIAVEL "VALOR_DEBITO")
PEGA_VALOR_DEBITO: 	
	
	JNB P1.3, PULA_VALOR_4_EIXOS	
		MOV VALOR_DEBITO, #10
		MOV DPTR, #MSG_4_EIXOS		
		JMP PULA_FIM_VALOR_DEBITO
	PULA_VALOR_4_EIXOS:
	
	JNB P1.2, PULA_VALOR_3_EIXOS
		MOV VALOR_DEBITO, #7
		MOV DPTR, #MSG_3_EIXOS
		JMP PULA_FIM_VALOR_DEBITO
	PULA_VALOR_3_EIXOS:
	
	JNB P1.1, PULA_VALOR_CARRO
		MOV VALOR_DEBITO, #5
		MOV DPTR, #MSG_CARRO
		JMP PULA_FIM_VALOR_DEBITO
	PULA_VALOR_CARRO:
	
	MOV VALOR_DEBITO, #0
	MOV DPTR, #MSG_MOTO
		
	PULA_FIM_VALOR_DEBITO:
	
	CALL LCD_LIMPA_TELA
	CALL LCD_ENVIA_FRASE
RET

;------------------------------------------------------
; AGUARDA PAGAMENTO DO DEBITO
AGUARDA_PAGAMENTO:
	; SE VALOR_DEBITO FOR 0 RETORNA IMEDIATAMENTE
	MOV A, VALOR_DEBITO
	JNZ AP_RUN
		RET
	AP_RUN:

	; Habilita RN (Recebimento de notas)
	SETB P1.6
	; DEFINE PARAMETRO PARA ITERACOES A CADA SEGUNDO
	MOV R0, #1
	
	CALL RESETA_LUZ_ALERTA
	AP_LOOP:

		CLR C
		
		; CHECA SE FOI INSERIDA NOTA DE 2 (N2)
		JNB	P1.4, AP_PULA_NOTA_2	
			SUBB A, #2
			;CLR P1.4
			CALL RESETA_LUZ_ALERTA
		AP_PULA_NOTA_2:

		JNB	P1.5, AP_PULA_NOTA_5
			SUBB A, #5
			;CLR P1.5
			CALL RESETA_LUZ_ALERTA
		AP_PULA_NOTA_5:		
		
		; CASO VALOR FIQUE NEGATIVO SAI DO LOOP
		JC AP_TROCO
		
		; EXECUTA VERIFICAÇÃO E ATIVA/DESATIVA LUZ SE NECESSARIO
		CALL STATUS_LUZ_ALERTA		

		CALL AGUARDA_N_SEGUNDOS

	JNZ AP_LOOP
	
	JMP AP_RET
	
	AP_TROCO:
	; Desabilita RN (Recebimento de notas)
	CLR P1.6
		CALL DA_TROCO

	AP_RET:
	; Desabilita RN (Recebimento de notas)
	CLR P1.6

	
RET

RESETA_LUZ_ALERTA:
	MOV R1, #TEMPO_LIGA_ALERTA
	MOV R2, #1
	CLR P3.5
RET

STATUS_LUZ_ALERTA:
DJNZ R1, AP_PULA_LUZ
	MOV R1, #1
	DJNZ R2, AP_PULA_LUZ
		MOV R2, #TEMPO_LUZ_ALERTA
		JB P3.5, AP_DESATIVA_LUZ
			SETB P3.5
			JMP AP_PULA_LUZ
		AP_DESATIVA_LUZ:
			CLR P3.5			
AP_PULA_LUZ:
RET

;------------------------------------------------------
; DA TROCO AO MOTORISTA ATE O VALOR DO ACUMULADOR VIRAR 0
DA_TROCO:	
	CLR C
	;CONVERTE PARA VALOR ABSOLUTO
	XRL A, #0FFh
	
	
	; 1 SEGUNDO ENTRE AS OPERAÇÕES
	MOV R0, #1
			
	DT_LOOP:
		CLR C
	
		CALL LCD_ESCREVE_TROCO
		
		; LIBERA MOEDA (LM)
		SETB P3.3		
		CALL AGUARDA_N_SEGUNDOS

		; FECHA LIBERA MOEDA (LM)
		CLR P3.3
		CALL AGUARDA_N_SEGUNDOS

		; ABRE SM (REPOEM MOEDA)
		SETB P3.2
		CALL AGUARDA_N_SEGUNDOS

		; FECHA SM
		CLR P3.2
		CALL AGUARDA_N_SEGUNDOS
		
		CLR C
		SUBB A, #1

	JNZ DT_LOOP
	
	CALL LCD_ESCREVE_TROCO

RET

LCD_ESCREVE_TROCO:
	CALL LCD_LIMPA_TELA
	MOV DPTR, #MSG_TROCO
	CALL LCD_ENVIA_FRASE
	CALL LCD_ENVIA_VALOR_A
RET

LCD_ENVIA_VALOR_A:
		PUSH ACC
		ADD A, #48
		CALL LCD_ENVIA_CHAR
		POP ACC
RET

;------------------------------------------------------
; SINALIZA ABERTURA DA CANCELA (AC = 1)
ABRE_CANCELA: 
	CALL LCD_LIMPA_TELA
	SETB P1.7
	MOV DPTR, #MSG_CANCELA_ABERTA
	CALL LCD_ENVIA_FRASE
RET

;------------------------------------------------------
; AGUARDA VEICULO PASSAR PELO PEDAGIO (S1 = 0 INDICA A PASSAGEM DO VEICULO)
AGUARDA_PASSAGEM_VEICULO:
	APV_LOOP:
	JB P1.0, APV_LOOP
RET
	
;------------------------------------------------------
; AGUARDA N SEGUNDOS (R0 DEVE CONTER O NUMERO DE SEGUNDOS A SEREM ESPERADOS)
AGUARDA_N_SEGUNDOS:
	PUSH 0
	PUSH 1
	ANS_LOOP:	
		MOV R1, #20
		ANS_SEC_LOOP:
			CLR TF2
			SETB TR2
			JNB TF2, $	
			CLR TR2			
		DJNZ R1, ANS_SEC_LOOP
	DJNZ R0, ANS_LOOP
	POP 1
	POP 0

RET		





;------------------------------------------------------
; STEPS DE INICIALIZACAO DO LCD
LCD_INIT_STEP1:
	MOV DPTR, #LCD_COMANDO
	MOV A, #38h
	MOVX @DPTR, A		
	CALL ATRASO_LCD
RET

;------------------------------------------------------
; STEPS DE INICIALIZACAO DO LCD
LCD_INIT_STEP2:
	; Controle LCD - 0 0 0 0 1 D C B
	; 			   - 0 0 0 0 1 1 0 0 ou 0Ch
	
	MOV DPTR, #LCD_COMANDO
	MOV A, #0Ch
	MOVX @DPTR, A	
	CALL ATRASO_LCD
	
	; Exibição LCD - 0 0 0 0 0 1 I/D S
	; 			   - 0 0 0 0 1 1  1  0  ou 06h
	MOV DPTR, #LCD_COMANDO
	MOV A, #06h
	MOVX @DPTR, A	
	CALL ATRASO_LCD
RET

;------------------------------------------------------
; LIMPA TELA DO LCD
LCD_LIMPA_TELA:
	PUSH ACC
	PUSH DPH
	PUSH DPL
	MOV DPTR, #LCD_COMANDO
	MOV A, #1
	MOVX @DPTR, A	
	CALL ATRASO_LIMPA_LCD
	POP DPL
	POP DPH
	POP ACC
RET

;------------------------------------------------------
; ENVIA PARA O LCD O VALOR DO ACUMULADOR
LCD_ENVIA_CHAR:
	PUSH DPH
	PUSH DPL
	MOV DPTR, #LCD_DADO
	MOVX @DPTR, A	
	CALL ATRASO_LCD
	POP DPL
	POP DPH
RET

;------------------------------------------------------
; ENVIA MENSAGEM PARA O LCD (DPTR precisa estar alinhado na mensagem)
LCD_ENVIA_FRASE:
	PUSH ACC
	LEF_LOOP:	
		CLR A
		MOVC A, @A+DPTR

		JZ LEF_RETURN			

		PUSH DPH
		PUSH DPL	
		
		CALL LCD_ENVIA_CHAR

		POP DPL
		POP DPH

		INC DPTR
	JMP LEF_LOOP
LEF_RETURN:
POP ACC
RET


;------------------------------------------------------
; Atraso necessário para o display 
ATRASO_LCD: 
PUSH 0
	MOV R0, #18
	DJNZ R0, $
POP 0
RET

;------------------------------------------------------			
; Atraso necessário para limpar o display - 41 x 40us = 1,65ms
ATRASO_LIMPA_LCD:
PUSH 1
	MOV  R1, #41
	VOLTA_ATRASO_LIMPA_LCD:
	CALL ATRASO_LCD
	DJNZ R1, VOLTA_ATRASO_LIMPA_LCD
POP 1
RET



ORG 3000H
	MSG_AGUARDANDO_VEICULO:
	DB "Aguardando...", 0
ORG 3050H
	MSG_MOTO:
	DB "Moto RS 0,00", 0
ORG 3100H
	MSG_CARRO:
	DB "Carro RS 5,00", 0
ORG 30150H
	MSG_3_EIXOS:
	DB "3 Eixos RS 7,00", 0
ORG 3200H
	MSG_4_EIXOS:
	DB "4 Eixos RS 10,00", 0
ORG 3250H
	MSG_TROCO:
	DB "Troco: R$ ", 0
ORG 3300H
	MSG_CANCELA_ABERTA:
	DB "Cancela Aberta..", 0



END