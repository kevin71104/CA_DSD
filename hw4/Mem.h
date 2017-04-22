#ifndef MEM_H
#define MEM_H
#define MEMsize  256

class Mem {
private:
	int mem[MEMsize][4];
public:
	Mem ();
	int* getfromMem(const int);    //get the pointer to the 4-elements array
	void writetoMem(const int,int*);
};

#endif
