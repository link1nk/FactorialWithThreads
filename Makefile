all: thread
	@rm thread.o

thread.o: thread.asm
	nasm -f elf64 thread.asm -o thread.o

thread: thread.o
	gcc -no-pie thread.o -o thread

.PHONY: clean
clean:
	rm thread
