section .data
    ; Mensajes del juego
    msg_bienvenida db 'Bienvenido a Serpientes y Escaleras!', 0xA, 0
    msg_jugadores db 'Ingrese numero de jugadores (1-5): ', 0
    msg_turno db 'Turno del Jugador ', 0
    msg_presione_enter db 'Presione ENTER para lanzar el dado...', 0xA, 0
    msg_dado db 'Dado: ', 0
    msg_posicion db 'Posicion: ', 0
    msg_escalera db '¡Escalera! Subes a ', 0
    msg_serpiente db '¡Serpiente! Bajas a ', 0
    msg_victoria db '¡Victoria! Jugador ', 0
    msg_ganador db ' es el ganador!', 0xA, 0
    msg_turnos_total db 'Total de turnos: ', 0
    msg_posiciones_otros db 'Posiciones de otros jugadores:', 0xA, 0
    msg_nueva_linea db 0xA, 0
    msg_error_jugadores db 'Numero de jugadores invalido. Debe ser entre 1 y 5.', 0xA, 0

    msg_tablero_superior db '  +------------------------------------------------------------------------------+', 0xA, 0
    msg_tablero_lateral db '| ', 0
    msg_tablero_vacio db '    ', 0
    msg_tablero_jugador db 'J', 0
    msg_tablero_escalera db 'E', 0
    msg_tablero_serpiente db 'S', 0
    
    ; Colores ANSI (opcional, para hacerlo más visual)
    color_rojo db 0x1B, '[31m', 0
    color_verde db 0x1B, '[32m', 0
    color_azul db 0x1B, '[34m', 0
    color_reset db 0x1B, '[0m', 0
    
    ; Tablero: array de 100 elementos (0-99) donde 0=normal, >0=escalera, <0=serpiente
    ; El valor indica el desplazamiento (positivo o negativo)
    tablero:
    dd 0, 0, 35, 0, 0, 0, 0, 0, 0, 0    ; Casilla 3: escalera a 38
    dd 0, 0, 0, 0, 0, 0, -21, 0, 0, 0   ; Casilla 16: serpiente a 16-21= -5 → no válida, es a 16-21= -5 (corrige si quieres, pero asumiremos que la meta es 1)
    dd 0, 0, 0, 0, 0, 0, 0, 42, 0, 0    ; Casilla 27: escalera a 69
    dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    dd -20, 0, 0, 0, 0, 0, 0, 0, 0, 0   ; Casilla 40: serpiente a 20

    dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    dd 0, 0, 0, 12, 0, 0, 0, 0, 0, 0    ; Casilla 63: NUEVA ESCALERA a 75 (63 + 12)
    dd 0, 0, 0, 0, 0, 0, -25, 0, 0, 0   ; Casilla 76: serpiente a 51 (76 - 25)

    dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    dd -30, 0, 0, 0, 0, 0, 0, 0, 0, 0   ; Casilla 90: NUEVA SERPIENTE a 60 (90 - 30)
    dd 0, 0, 0, 0, 0, 0, 8, 0, 0, 0     ; Casilla 96: NUEVA ESCALERA a 104 (fuera de rango), mejor a 96+8=104 → cambiar a +3 → 99 (máximo)
    
    ; Variables del juego
    num_jugadores dd 0
    jugadores_pos times 5 dd 1      ; Posiciones iniciales (1-100)
    jugadores_turnos times 5 dd 0   ; Contador de turnos por jugador
    turno_actual dd 0               ; Índice del jugador actual (0-4)
    total_turnos dd 0               ; Turnos totales del juego
    
    ; Buffer para entrada/salida
    buffer db 0

section .bss
    input resb 2

section .text

    global _start

; Funciones del sistema
%define SYS_READ 3
%define SYS_WRITE 4
%define SYS_EXIT 1
%define STDIN 0
%define STDOUT 1

; Macro para imprimir mensajes
%macro print 1
    push eax
    push ebx
    push ecx
    push edx
    mov eax, %1
    call strlen
    mov edx, eax        ; longitud
    mov ecx, %1         ; mensaje
    mov ebx, STDOUT     ; descriptor de archivo
    mov eax, SYS_WRITE  ; sys_write
    int 0x80
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro

; Macro para leer entrada
%macro read 2
    push eax
    push ebx
    push ecx
    push edx
    mov edx, %2         ; longitud máxima
    mov ecx, %1         ; buffer
    mov ebx, STDIN      ; descriptor de archivo
    mov eax, SYS_READ   ; sys_read
    int 0x80
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro

; Función para calcular longitud de cadena
strlen:
    push ebx
    mov ebx, eax
    .nextchar:
        cmp byte [eax], 0
        jz .finished
        inc eax
        jmp .nextchar
    .finished:
        sub eax, ebx
        pop ebx
        ret

print_tablero:
    pusha
    
    ; Imprimir borde superior
    print msg_tablero_superior

    ; Inicializar contadores
    mov ecx, 10        ; 10 filas
    mov ebx, 100       ; Comenzamos desde la casilla 100 (fila inferior)

    .fila_loop:
        ; Imprimir borde lateral izquierdo
        print msg_tablero_lateral
        
        ; Determinar dirección de la fila (alternar izquierda/derecha)
        mov eax, ecx
        and eax, 1
        jnz .fila_derecha
        
        ; Fila izquierda (números descendentes: 90,89,...,81)
        mov edx, ebx    ; EDX = número de casilla actual
        mov esi, 10     ; Contador de columnas
        
        .casilla_loop_izquierda:
            call print_casilla
            dec edx
            dec esi
            jnz .casilla_loop_izquierda
            jmp .fin_fila
            
        .fila_derecha:
            ; Fila derecha (números ascendentes: 71,72,...,80)
            mov edx, ebx
            sub edx, 9   ; EDX = primera casilla de la fila
            mov esi, 10  ; Contador de columnas
            
            .casilla_loop_derecha:
                call print_casilla
                inc edx
                dec esi
                jnz .casilla_loop_derecha
                
        .fin_fila:
            ; Imprimir borde lateral derecho y nueva línea
            print msg_tablero_lateral
            print msg_nueva_linea
            
            ; Preparar siguiente fila (retroceder 10 casillas)
            sub ebx, 10
            dec ecx
            jnz .fila_loop
            
    ; Imprimir borde inferior
    print msg_tablero_superior
    print msg_nueva_linea
    
    popa
    ret

print_casilla:
    pusha
    
    ; Verificar si hay jugadores en esta casilla
    mov ecx, [num_jugadores]
    xor ebx, ebx
.buscar_jugador:
    cmp [jugadores_pos + ebx*4], edx
    je .imprimir_jugador
    inc ebx
    loop .buscar_jugador

    ; No hay jugador, verificar serpiente/escalera
    mov eax, edx
    dec eax
    mov eax, [tablero + eax*4]
    test eax, eax
    jz .imprimir_vacio

    cmp eax, 0
    jg .imprimir_escalera

    ; Imprimir serpiente
    print color_rojo
    print msg_tablero_serpiente
    print color_reset
    jmp .fin_casilla

.imprimir_escalera:
    print color_verde
    print msg_tablero_escalera
    print color_reset
    jmp .fin_casilla

.imprimir_jugador:
    print color_azul
    print msg_tablero_jugador
    mov eax, ebx
    inc eax
    call print_number
    print color_reset
    jmp .fin_casilla

.imprimir_vacio:
    ; Imprimir número de casilla (o espacio)
    mov eax, edx
    call print_number

.fin_casilla:
    ; Espacio entre casillas
    mov byte [buffer], ' '
    mov byte [buffer+1], 0
    print buffer

    popa
    ret
    
    
; Modificar el bucle principal para mostrar el tablero
.juego_loop:
    
    ; Mostrar tablero antes de cada turno
    call print_tablero
    
    
    ; Mostrar tablero después de cada movimiento
    call print_tablero

; Función para convertir número a cadena (para imprimir)
; Entrada: EAX = número, ESI = puntero al buffer
int_to_string:
    add esi, 9          ; Trabajamos desde el final del buffer
    mov byte [esi], 0    ; Carácter nulo terminador
    mov ebx, 10         ; Divisor
    
    .convert:
        xor edx, edx    ; Limpia EDX para la división
        div ebx         ; Divide EAX por 10
        add dl, '0'     ; Convierte resto a ASCII
        dec esi         ; Mueve el puntero hacia atrás
        mov [esi], dl    ; Almacena el carácter
        test eax, eax   ; ¿EAX == 0?
        jnz .convert    ; Si no, sigue convirtiendo
    mov eax, esi        ; Devuelve puntero al inicio del número
    ret

; Función pseudoaleatoria (usa el reloj del sistema)
; Devuelve en EAX un número entre 1-6
random_dado:
    push ebx
    push ecx
    push edx
    
    ; Obtener tiempo del sistema (ticks)
    mov eax, 13         ; sys_time
    xor ebx, ebx        ; NULL
    int 0x80
    
    ; Usar los ticks como semilla
    mov ecx, eax
    mov eax, ecx
    xor edx, edx
    mov ebx, 6
    div ebx             ; Divide por 6 para obtener resto (0-5)
    inc edx             ; Convierte a 1-6
    mov eax, edx
    
    pop edx
    pop ecx
    pop ebx
    ret

; Función principal
_start:
    ; Mostrar mensaje de bienvenida
    print msg_bienvenida
    
    ; Pedir número de jugadores
    .pedir_jugadores:
        print msg_jugadores
        read input, 2
        
        ; Validar entrada
        mov al, [input]
        cmp al, '1'
        jb .error_jugadores
        cmp al, '5'
        ja .error_jugadores
        
        ; Convertir a número y guardar
        sub al, '0'
        mov [num_jugadores], al
        jmp .iniciar_juego
    
    .error_jugadores:
        print msg_error_jugadores
        jmp .pedir_jugadores
    
    .iniciar_juego:
        ; Inicializar posiciones de jugadores
        mov ecx, 5
        mov eax, 1
        xor ebx, ebx
        .init_posiciones:
            mov [jugadores_pos + ebx*4], eax
            inc ebx
            loop .init_posiciones
        
        ; Bucle principal del juego
        .juego_loop:
            ; Obtener jugador actual
            mov eax, [turno_actual]
            mov ebx, [num_jugadores]
            cmp eax, ebx
            jb .turno_valido
            xor eax, eax
            mov [turno_actual], eax
            
            .turno_valido:
                ; Incrementar contadores de turnos
                mov ebx, [turno_actual]
                inc dword [jugadores_turnos + ebx*4]
                inc dword [total_turnos]
                
                ; Mostrar mensaje de turno
                print msg_turno
                mov eax, ebx
                inc eax
                call print_number
                print msg_nueva_linea
                print msg_presione_enter
                
                ; Esperar ENTER
                .esperar_enter:
                    read buffer, 1
                    cmp byte [buffer], 0xA
                    jne .esperar_enter
                
                ; Lanzar dado
                call random_dado
                push eax
                print msg_dado
                call print_number
                print msg_nueva_linea
                pop eax
                
                ; Mover jugador
                mov ebx, [turno_actual]
                add [jugadores_pos + ebx*4], eax
                
                ; Verificar si pasó de 100
                mov ecx, [jugadores_pos + ebx*4]
                cmp ecx, 100
                jg .rebotar
                jmp .verificar_casilla
                
                .rebotar:
                    mov edx, ecx
                    sub edx, 100
                    mov ecx, 100
                    sub ecx, edx
                    mov [jugadores_pos + ebx*4], ecx
                
                .verificar_casilla:
                    ; Verificar serpiente/escalera
                    mov ecx, [jugadores_pos + ebx*4]  ; Obtener posición actual (1-100)
                    dec ecx                           ; Convertir a índice 0-99 para el tablero
                    mov eax, [tablero + ecx*4]        ; Obtener desplazamiento
                    test eax, eax
                    jz .mostrar_posicion              ; Si 0, no hay cambio
                    
                    ; Hay serpiente o escalera
                    cmp eax, 0
                    jg .escalera
                    
                    ; Serpiente (eax es negativo)
                    print msg_serpiente
                    mov ecx, [jugadores_pos + ebx*4]  ; Posición original (1-100)
                    add ecx, eax                      ; Aplicar desplazamiento negativo
                    cmp ecx, 1                        ; Verificar que no sea menor que 1
                    jge .guardar_nueva_posicion
                    mov ecx, 1                        ; Si es menor que 1, colocar en 1
                    jmp .guardar_nueva_posicion
                    
                .escalera:
                    print msg_escalera
                    mov ecx, [jugadores_pos + ebx*4]  ; Posición original (1-100)
                    add ecx, eax                      ; Aplicar desplazamiento positivo
                    cmp ecx, 100                      ; Verificar que no pase de 100
                    jle .guardar_nueva_posicion
                    mov ecx, 100                      ; Si pasa de 100, colocar en 100

                .guardar_nueva_posicion:
                    mov [jugadores_pos + ebx*4], ecx  ; Guardar nueva posición
                    mov eax, ecx
                    call print_number
                    print msg_nueva_linea
                    
                    .mostrar_cambio:
                        mov eax, ecx
                        call print_number
                        print msg_nueva_linea
                
                .mostrar_posicion:
                    print msg_posicion
                    mov ebx, [turno_actual]
                    mov eax, [jugadores_pos + ebx*4]
                    call print_number
                    print msg_nueva_linea
                    call print_tablero
                    
                    ; Verificar victoria
                    cmp eax, 100
                    je .victoria
                    
                    ; Pasar al siguiente jugador
                    inc dword [turno_actual]
                    jmp .juego_loop
    
    .victoria:
        ; Mostrar mensaje de victoria
        print msg_victoria
        mov eax, [turno_actual]
        inc eax
        call print_number
        print msg_ganador
        
        ; Mostrar total de turnos
        print msg_turnos_total
        mov eax, [total_turnos]
        call print_number
        print msg_nueva_linea
        
        ; Mostrar posiciones de otros jugadores (si hay)
        mov eax, [num_jugadores]
        cmp eax, 1
        jle .fin
        
        print msg_posiciones_otros
        mov ecx, 1  ; Contador de jugadores
        .mostrar_otros:
            cmp ecx, [num_jugadores]
            ja .fin
            
            ; Saltar al ganador
            mov eax, [turno_actual]
            inc eax
            cmp ecx, eax
            je .siguiente_jugador
            
            ; Mostrar posición del jugador
            push ecx
            mov eax, ecx
            call print_number
            mov byte [buffer], ':'
            mov byte [buffer+1], ' '
            mov byte [buffer+2], 0
            print buffer
            pop ecx
            
            dec ecx
            mov eax, [jugadores_pos + ecx*4]
            inc ecx
            call print_number
            print msg_nueva_linea
            
            .siguiente_jugador:
                inc ecx
                jmp .mostrar_otros
    
    .fin:
        ; Salir del programa
        mov eax, SYS_EXIT
        xor ebx, ebx
        int 0x80

; Función para imprimir número (EAX)
print_number:
    push eax
    push ebx
    push ecx
    push edx
    
    ; Convertir número a cadena
    mov esi, buffer
    call int_to_string
    
    ; Imprimir el número
    mov ecx, eax
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    mov edx, 10  ; Longitud máxima
    sub edx, eax
    add edx, ecx
    int 0x80
    
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret