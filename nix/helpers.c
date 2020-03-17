#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include "csound.h"
#include "csoundCore.h"

#include <sys/stat.h>

// returns the address of a string
// pointer which is writable from js
char* allocStringMem (int length) {
  char *ptr = NULL;
  ptr = malloc((length * sizeof(char)) + 1);
  return ptr;
}

// free the allocated String Memory
// (this could be unneccecary, dont know)
void freeStringMem (char* ptr) {
  free(ptr);
}

CSOUND_PARAMS* allocCsoundParams() {
  CSOUND_PARAMS* ptr = NULL;
  ptr = malloc(sizeof(CSOUND_PARAMS));
  return ptr;
}

void freeCsoundParams(CSOUND_PARAMS* ptr) {
  free(ptr);
}

int createFileDebug(int dirFd) {
  FILE * fPtr;
  int fd;
  fPtr = fopen("/csound/file1.txt", "w");
  fd = openat(dirFd, "/csound/file1.txt", 0);
  printf("FD: %d \n", fd);
  char path[] = "/csound";

  /* fopen() return NULL if last operation was unsuccessful */
  if(fPtr == NULL)
    {
      /* File not created hence exit */
      printf("Unable to create file.\n");
      return 1;
      /* exit(EXIT_FAILURE); */
    }

  /* Write data to file */
  fputs("Hello heimur!", fPtr);
  /* Close file to save file data */
  fclose(fPtr);
  /* Success message */
  printf("File created and saved successfully. :) \n");
  return 0;
}

// DUMMY MAIN (never called, but is needed)
int main (int argc, char *argv[] ) {}

/* int sizeofCsoundParams () { */
/*   return sizeof(CSOUND_PARAMS); */
/* } */

/* // get the sizeof int */
/* int sizeofInt () { */
/*   return sizeof(int); */
/* } */
