#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <climits>
#include <cmath>
#include "L1cache.h"
#include "Mem.h"
using namespace std;

//direct map for 1, 2-way for 2, 4-way for 4, fully associative for 8
L1cache::L1cache (Mem* memory, int way = 1){
	L1readhit = 0;
	L1readmiss = 0;
	L1writehit = 0;
	L1writemiss = 0;
	way_number = way;
	set_num = L1size / way_number;
	mem = memory;
	for(int i=0; i < L1size; i++) {
		for (int j=0; j < 4; j++) {
			cache[i][j] = 0;
		}
	}
}

// address is word-addressing
int L1cache::getfromCache(const int address)
{
	int shift =  2 + log2(set_num);  // right shift how many bits to get tag
	int tag = (address >> shift);
	int data_label = address % 4;  // index of which word in the block
	int set_label = (address >> 2) % set_num ;  // which set
	int block_label = 0;

	for(unsigned i = 0; i < way_number; i++){
		int temp_label = set_label * way_number + i;
		// get block with the smallest release bits
		if(i == 0)
			block_label = temp_label;
		else{
			if(cache[block_label][2] > cache[temp_label][2])
				block_label = temp_label;
		}
        // valid = 1
		if (cache[temp_label][0]){
			if (cache[temp_label][3] == tag){
				L1readhit ++;
				cache[temp_label][2] = INT_MAX;
				// let other blocks release bit decrease(be replaced first)
				for(unsigned j = 0; j < L1size; j++)
					if(j != temp_label)
					    cache[j][2]--;
				return cache[temp_label][4 + data_label];
			}
		}
	}

	L1readmiss++;
	int* dataptr = mem -> getfromMem(address >> 2);
	// write back
	if(cache[block_label][1] == 1){
	    int write_add = (cache[block_label][3] << (shift-2)) + set_label;
		//cout << "write_add" << write_add;
	    mem -> writetoMem(write_add, &(cache[block_label][4]) );
    }
	// get new data
	for(unsigned i = 0; i < 4; i++)
	    cache[block_label][4 + i] = dataptr[i];
    cache[block_label][0] = 1;
	cache[block_label][1] = 0;
	cache[block_label][2] = INT_MAX;
	cache[block_label][3] = tag;
	for(unsigned j = 0; j < L1size; j++)
		if(j != block_label)
			cache[j][2]--;
	return cache[block_label][4 + data_label];
}

void L1cache::writetoCache(const int address,const int indata)
{
	int shift =  2 + log2(set_num);  // right shift how many bits to get tag
	int tag = (address >> shift);
	int data_label = address % 4;  // index of which word in the block
	int set_label = (address >> 2) % set_num ;  // which set
	int block_label = 0;

	for(unsigned i = 0; i < way_number; i++){
		int temp_label = set_label * way_number + i;
		// get block with the smallest release bits
		if(i == 0)
			block_label = temp_label;
		else{
			if(cache[block_label][2] > cache[temp_label][2])
				block_label = temp_label;
		}
		// valid = 1
		if (cache[temp_label][0]){
			if (cache[temp_label][3] == tag){
				L1writehit++;
				cache[temp_label][1] = 1;
				cache[temp_label][2] = INT_MAX;
				cache[temp_label][4 + data_label] = indata;
				// let other blocks release bit decrease(be replaced first)
				for(unsigned j = 0; j < L1size; j++)
					if(j != temp_label)
						cache[j][2]--;
			}
		}
	}

	L1writemiss++;
	int* dataptr = mem -> getfromMem(address >> 2);
	// write back
	if(cache[block_label][1] == 1){
		int write_add = (cache[block_label][3] << (shift - 2)) + set_label;
		//cout << "write_add" << write_add << '\n';
		mem -> writetoMem(write_add, &(cache[block_label][4]) );
	}
	// get new data
	for(unsigned i = 0; i < 4; i++)
		cache[block_label][4 + i] = dataptr[i];
	cache[block_label][0] = 1;
	cache[block_label][1] = 1;
	cache[block_label][2] = INT_MAX;
	cache[block_label][3] = tag;
	cache[block_label][4 + data_label] = indata;
	for(unsigned j = 0; j < L1size; j++)
		if(j != block_label)
			cache[j][2]--;
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
