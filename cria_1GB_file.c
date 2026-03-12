#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

#define FILE_SIZE (1024LL * 1024 * 1024)  // 1 GB

int main(void) {
    int fd = open("ficheiro_1GB.bin", O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd == -1) {
        perror("open");
        return 1;
    }

    // Move o offset para 1GB
    off_t pos = lseek(fd, FILE_SIZE, SEEK_SET);
    if (pos == (off_t)-1) {
        perror("lseek");
        close(fd);
        return 1;
    }

    // Escreve 1 byte no final -> cria ficheiro sparse
    if (write(fd, "", 1) != 1) {
        perror("write");
        close(fd);
        return 1;
    }

    close(fd);
    printf("Ficheiro sparse de 1GB criado com sucesso!\n");

    return 0;
}
