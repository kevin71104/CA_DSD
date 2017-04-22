#include<iostream>
#include<stdio.h>
#include<stdlib.h>
#include "L1cache.h"
#include "Mem.h"
using namespace std;

L1cache::L1cache (Mem* memory,int way = 1) {
	L1readhit = 0;
	L1readmiss = 0;
	L1writehit = 0;
	L1writemiss = 0;
	mem = memory;
	way_number = way;
	for(int i=0; i < L1size; i++) {
		for (int j=0; j < 4; j++) {
			cache[i][j] = 0;
		}
	}
}

int L1cache::getfromCache(const int address){

	//==================================================
	//===			TODO		 	 ===
	//==================================================
	return 0;
}

void L1cache::writetoCache(const int address,const int indata){
	//==================================================
        //===                   TODO                     ===
        //==================================================

}

int L1cache::getReadHit(void){
	int temp = L1readhit;
	return temp;
}
int L1cache::getReadMiss(void){
	int temp = L1readmiss;
	return temp;
}
int L1cache::getWriteHit(void){
	int temp = L1writehit;
	return temp;
}
int L1cache::getWriteMiss(void){
	int temp = L1writemiss;
	return temp;
}
int L1cache::getHit(void){
	int temp = L1readhit + L1writehit;
	return temp;
}
int L1cache::getMiss(void){
	int temp = L1readmiss + L1writemiss;
	return temp;
}
