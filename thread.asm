;************************************************************************
; Fatorial com Threads (Código Fonte)
;
; Autor: Lincoln Dias
;
; Criação:      17 Mar 2024
; Atualização:  17 Mar 2024
;
; Descrição:  Esse programa tem como objetivo exemplificar o uso de
;             threads para otimização de tarefas, fazendo com que
;             os calculos ocorram concorrentemente, mas para uma
;             visão melhor disso acontecendo, após cada calculo
;             a thread dorme por 1 segundo. O numero da thread é
;             correspondente ao seu TID.
;
;
;************************************************************************

; Informa ao nasm que será usado o conjunto de intruções x86-64
bits 64
; Define como padrão o endereçamento relativo ao RIP, evitando a criação de
; simbolos de realocação
default rel

; Funções externas
extern printf
extern scanf
extern malloc
extern clone
extern waitpid
extern gettid
extern putchar
extern sleep
extern free

; Diretivas para Pulo de Linha, e Caractere Nulo
%define LF   0x0A
%define NULL 0x00

; Ativa a proteção DEP/NX
section .note.GNU-stack noalloc noexec nowrite progbits

; Seção de dados Read Only
section .rodata
    fmt_spec:  db "%llu", NULL
    fmt_spec2: db "%d",   NULL

    informe_qtde_calculos: db "Informe a quantidade de calculos a ser realizado: ", NULL
    informe_calculo:       db "Informe o calculo %d: ", NULL

    thread_iniciada: db "Thread (%zu) - Iniciada!", LF, NULL
    msg_fatorial:    db "Thread (%zu) - %d (calculo iteracao: %d)", LF, NULL

    print_resultado: db "Thread (%zu) - Fatorial(%d): Resultado: %zu", LF, NULL

; Seção de código executável
section .text
    global main ; Exportando simbolo

;------------------------------------------------------------------------
;          Função: (thread_func) Descrição, Argumentos e Retorno
;------------------------------------------------------------------------
; Descrição: Depois da main essa é a principal função nesse código, é
;            ela que irá calcular o fatorial dos numeros e a cada iteração
;            printar na tela.
;------------------------------------------------------------------------
; RDI (argumento): Argumento passado para a thread, nele contem as
;                  iterações que deverão ser feitas e um campo 
;                  para armazenar o resultado.
;------------------------------------------------------------------------
; RAX (Retorno): Valor de retorno: Código de erro da função (0 - Sucesso)
;------------------------------------------------------------------------
thread_func:
    ; Prologo da função
    push rbp
    mov rbp, rsp
    sub rsp, 0x30
    
%define thread_id rbp-0xc

    ; Pega o TID e imprime a mensagem que a thread iniciou
    mov [rbp-0x28], rdi
    call gettid
    mov [thread_id], eax
    mov rax, [rbp-0x28]
    mov [rbp-0x18], rax
    mov rax, [rbp-0x18]
    mov eax, [rax]
    mov [rbp-0x1c], eax
    mov dword[rbp-0x4], 1
    mov eax, [rbp-0xc]
    mov esi, eax
    lea rax, [thread_iniciada]
    mov rdi, rax
    mov eax, 0
    call printf
    
    ; Começa o calculo do fatorial
    mov eax, [rbp-0x1c]
    mov [rbp-0x8], eax
    jmp .checkFatorial
    .loopFatorial:
    mov eax, [rbp-0x4]
    imul eax, [rbp-0x8]
    mov [rbp-0x4], eax
    mov ecx, [rbp-0x4]
    mov edx, [rbp-0x8]
    mov eax, [rbp-0xc]
    mov esi, eax
    lea rax, [msg_fatorial]
    mov rdi, rax
    mov eax, 0
    call printf
    
    ; Dorme 1 segundo
    mov edi, 1
    call sleep

    sub dword[rbp-0x8], 1

    .checkFatorial:
    cmp dword[rbp-0x8], 1
    jg .loopFatorial

    ; Armazena o resultado
    mov eax, [rbp-0x4]
    movsxd rdx, eax
    mov rax, [rbp-0x18]
    mov [rax+8], rdx
    mov eax, 0

    ; Epilogo da função thread
    leave
    ret

main:
    ; Prologo da função main
    push rbp
    mov rbp,rsp
    push rbx
    sub rsp,0x48

; Diretivas de pre-processamento para auxiliar na localização de variaveis locais
%define qtde_calculos rbp-0x50
%define pids          rbp-0x48
%define stacks        rbp-0x40
%define stack_size    rbp-0x34
%define t_args        rbp-0x30
%define loop_control6 rbp-0x28
%define loop_control5 rbp-0x24
%define loop_control4 rbp-0x20
%define loop_control3 rbp-0x1c
%define loop_control2 rbp-0x18
%define loop_control  rbp-0x14

    ; Pergunta a quantidade de calculos
    mov qword [qtde_calculos], 0x0
    lea rdi, [informe_qtde_calculos]
    xor eax, eax
    call printf

    ; Entrada do usuario
    lea rsi, [qtde_calculos]
    lea rdi, [fmt_spec]
    xor eax, eax
    call scanf

    ; Aloca memoria para o t_args (argumentos para as threads)
    mov rdi, [qtde_calculos]
    shl rdi, 4 ; Equivalente a "imul rdi, 16" porém mais eficiente xD
    call malloc
    mov [t_args], rax

    ; Loop para perguntar cada calculo ao usuario
    mov dword[loop_control], 0
    jmp .checkLoopCalculos
    .loopCalculos:
    mov esi, [loop_control]
    inc esi
    lea rdi, [informe_calculo]
    xor eax, eax
    call printf

    mov eax, [loop_control]
    cdqe
    shl rax, 4
    mov rdx, rax
    mov rax, [t_args]
    add rax, rdx
    mov rsi, rax
    lea rdi, [fmt_spec2]
    xor eax, eax
    call scanf
    
    add dword[loop_control], 1

    .checkLoopCalculos:
    mov eax, [loop_control]
    movsxd rdx, eax
    mov rax, [qtde_calculos]
    cmp rdx, rax
    jb .loopCalculos

    ; Cria a stack para as threads
    mov dword [stack_size], 0x10000 ; 65536
    mov rdi, [qtde_calculos]
    shl rdi, 3
    call malloc
    mov [stacks], rax

    mov dword[loop_control2], 0
    jmp .checkLoopStacks    
    .loopStacks:
    mov eax, [stack_size]
    cdqe
    mov edx, [loop_control2]
    movsxd rdx, edx
    lea rcx, [rdx*8]
    mov rdx, [stacks]
    lea rbx, [rcx+rdx]
    mov rdi, rax
    call malloc
    mov [rbx], rax
    
    add dword[loop_control2], 1
    
    .checkLoopStacks:
    mov eax, [loop_control2]
    movsxd rdx, eax
    mov rax, [qtde_calculos]
    cmp rdx, rax
    jb .loopStacks    

    ; Aloca um vetor de PID para guardar os TID das threads
    ; *NOTA: O tipo pid_t serve tanto para armazenar PID e TID
    mov rax, [qtde_calculos]
    shl rax, 2
    mov rdi, rax
    call malloc
    mov [pids], rax
    
    ; Cria as Threads
    ; *NOTA: Em sistemas linux, a criação de threads e processos são
    ;        ambas feitas pela syscall clone (também é essa a implementação
    ;        na biblioteca pthreads para threads, e na função fork para processos),
    ;        oque difere a criação de uma thread e um processo é a presença da flag
    ;        VM_CLONE, quando ela aparece é criado uma thread, se não, processo.
    mov dword[loop_control3], 0
    jmp .checkCreateThreads
    .loopCreateThreads:
    mov eax, [loop_control3]
    cdqe
    shl rax, 4
    mov rdx, rax
    mov rax, [t_args]
    add rdx, rax
    mov eax, [loop_control3]
    cdqe
    lea rcx, [rax*8]
    mov rax, [stacks]
    add rax, rcx
    mov rcx, [rax]
    mov eax, [stack_size]
    cdqe
    add rax, rcx
    mov ecx, [loop_control3]
    movsxd rcx, ecx
    lea rsi, [rcx*4]
    mov rcx, [pids]
    lea rbx, [rsi+rcx]
    mov rcx, rdx
    mov rdx, 0x111 ; (FLAGS) 0x111 = VM_CLONE | SIGCHLD
    mov rsi, rax
    lea rax, [thread_func]
    mov rdi, rax
    xor eax, eax
    call clone

    mov [rbx], eax
    add dword[loop_control3], 1

    .checkCreateThreads:
    mov eax, [loop_control3]
    movsxd rdx, eax
    mov rax, [qtde_calculos]
    cmp rdx, rax
    jb .loopCreateThreads

    ; Aguarda todas as threads finalizarem
    mov dword[loop_control4], 0
    jmp .checkWaitThreads
    .loopWaitThreads:
    mov eax, [loop_control4]
    cdqe
    lea rdx, [rax*4]
    mov rax, [pids]
    add rax, rdx
    mov eax, [rax]
    mov edx, 0
    mov esi, 0
    mov edi, eax
    call waitpid

    add dword[loop_control4], 1

    .checkWaitThreads:
    mov eax, [loop_control4]
    movsxd rdx, eax
    mov rax, [qtde_calculos]
    cmp rdx, rax
    jb .loopWaitThreads

    ; Imprime uma nova linha
    mov edi, 0xa
    call putchar

    ; Imprime o resultados de cada thread de forma organizada
    mov dword[loop_control5], 0
    jmp .checkPrintResultados
    .loopPrintResultados:
    mov eax, [loop_control5]
    cdqe
    shl rax, 4
    mov rdx, rax
    mov rax, [t_args]
    add rax, rdx
    mov rcx, [rax + 8]
    mov eax, [loop_control5]
    cdqe
    shl rax, 4
    mov rdx, rax
    mov rax, [t_args]
    add rax, rdx
    mov edx, [rax]
    mov eax, [loop_control5]
    cdqe
    lea rsi, [rax*4]
    mov rax, [pids]
    add rax, rsi
    mov eax, [rax]
    mov esi, eax
    lea rax, [print_resultado]
    mov rdi, rax
    mov eax, 0
    call printf

    add dword[loop_control5], 1    

    .checkPrintResultados:
    mov eax, [loop_control5]
    movsxd rdx, eax
    mov rax, [qtde_calculos]
    cmp rdx, rax
    jb .loopPrintResultados

    ; Liberação das memorias alocadas    
    mov rdi, [t_args]
    call free
    
    mov dword[loop_control6], 0
    jmp .checkFreeStacks
    .loopFreeStacks:
    mov eax, [loop_control6]
    cdqe
    lea rdx, [rax*8]
    mov rax, [stacks]
    add rax, rdx
    mov rax, [rax]
    mov rdi, rax
    call free

    add dword[loop_control6], 1

    .checkFreeStacks:
    mov eax, [loop_control6]
    movsxd rdx, eax
    mov rax, [qtde_calculos]
    cmp rdx, rax
    jb .loopFreeStacks

    mov rdi, [stacks]
    call free

    mov rdi, [pids]
    call free

    xor eax, eax

    ; Epilogo da função main
    mov rbx, [rbp-0x8]
    leave 
    ret


