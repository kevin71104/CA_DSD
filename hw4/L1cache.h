#ifndef L1CACHE_H
#define L1CACHE_H
#define L1size  8    //the number of blocks of L1-cache
#define MEMsize  256
#include "Mem.h"
class L1cache {
private:
	int  L1readmiss;
	int  L1readhit;
	int  L1writemiss;
	int  L1writehit;
	int  cache[L1size][8];  //0:valid 1:dirty bit 2:release bit 3:tag 4:data0 5:data1 6:data2 7:data3
	Mem* mem;
	int  way_number;
	int  set_num;  //the number of sets
public:
	L1cache (Mem* , int );
	int  getfromCache(const int);
	void writetoCache(const int,const int);
	int  getReadHit(void);
	int  getReadMiss(void);
	int  getWriteHit(void);
	int  getWriteMiss(void);
	int  getHit(void);
	int  getMiss(void);
};

#endif
