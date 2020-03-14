#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "csound.h"
#include "csoundCore.h"

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

/* int sizeofCsoundParams () { */
/*   return sizeof(CSOUND_PARAMS); */
/* } */

/* // get the sizeof int */
/* int sizeofInt () { */
/*   return sizeof(int); */
/* } */
