#include <stdio.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <string.h>
int main(void){
  unsigned long sizes[]={2UL<<30, 16UL<<30, 64UL<<30, 256UL<<30, 1UL<<40, 16UL<<40, 64UL<<40};
  for(int i=0;i<7;i++){
    for(int nr=0;nr<2;nr++){
      int fl=MAP_PRIVATE|MAP_ANONYMOUS|(nr?MAP_NORESERVE:0);
      void*p=mmap(0,sizes[i],PROT_READ|PROT_WRITE,fl,-1,0);
      if(p==MAP_FAILED){printf("%6lu GiB %-10s FAILED\n",sizes[i]>>30,nr?"NORESERVE":"plain");continue;}
      memset((char*)p+sizes[i]-4096,1,4096);
      struct rusage r; getrusage(RUSAGE_SELF,&r);
      printf("%6lu GiB %-10s ok   maxrss=%ld KB\n",sizes[i]>>30,nr?"NORESERVE":"plain",r.ru_maxrss);
      munmap(p,sizes[i]);
    }
  }
}
