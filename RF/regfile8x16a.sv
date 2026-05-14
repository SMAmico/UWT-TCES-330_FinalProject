//regfile8x16
//Seth Amico, John Teal
//TCES330

/*
	the regfile is a set of 8 segments of 16-bit logic variables defined in verilog and accessed as follows:
	
	CLOCK
		the clock line defines when input or control wires are read and evaluated. the clock triggers this on the rising edge,
		and any changes to the control lines during other clock periods are ignored.
	
	WRITE CONTROL DATAPATH
		the write enable line (write) defines when the external control module wants to write or change the values of a register in the RF.
		it is used with the write address and write data to define a clock cycle, location, and data halfword that the system writes to its registers via. 
		
		the write addresss (wrAddr) is a 3-bit bus that defines the register to be written to. it can address up to 8 registers (000 to 111).
		
		the write data (wrData) is a 16 bit bus that overwrites the value of a register previously selected by the wrAddr line. it sets the value, completely overwriting the previous value.
		
	DATAPATH A
		the register A read address (rdAddrA) is a 3-bit bus that determines the register address for the output A of the RF, and consecutively the input A of the ALU or an address in main memory.
		in this implementation, data can be written to the registers only if data is not being written to the registers. this can be changed if need be.
		
		the register A read data (rdDataA) is a 16-bit bus that mirrors the data stored in one of the regsiter addresses. if the write line is high,
		the output is not updated and remains at the previous value.
		
	DATAPATH B
		the register B read address (rdAddrB) is a 3-bit bus that determines the register address for the output B of the RF, and consecutively the input B of the ALU.
		in this implementation, data can be written to the registers only if data is not being written to the registers. this can be changed if need be.
		
		the register A read data (rdDataB) is a 16-bit bus that mirrors the data stored in one of the regsiter addresses. if the write line is high,
		the output is not updated and remains at the previous value.

*/

module regfile8x16a (
	input clk, 					 // system clock
	
	input write, 				 // write enable
	input [2:0] wrAddr,			 // write address
	input [15:0] wrData,		 // write data
	
	input [2:0] rdAddrA,		 // A-side read address
	output logic [15:0] rdDataA,		 // A-side read data
	
	input [2:0] rdAddrB, 		 // B-side read address
	output logic [15:0] rdDataB 		 // B-side read data
	); 
	logic [15:0] regfile [0:7]; 	 // 8 registers, each 16-bit

	always @(posedge clk) begin			//activate on the positive clock edge only

		//this implementation checks alu reading conditions first
		if(~write) begin 				//we check if write is low before we assign the outputs, to avoid giving the ALU resource conflicts/race conditions
		// read the registers
		rdDataA = regfile[rdAddrA];	//setting register read data values to the regfile index specified.
		rdDataB = regfile[rdAddrB];	//these are blocking assignments to allow simultaneous setting
		// write the registers
		end else begin
			regfile[wrAddr] = wrData;   //if write is asserted, copy the value from the regfile to the output value
			rdDataA = 16'b0;			//and set the output values to 0
			rdDataB = 16'b0;
		end
	end

endmodule



module regfile8x16a_tb();
	reg clk; 					// system clock
	
	reg write;				 	// write enable
	reg [2:0] wrAddr;			// write address
	reg [15:0] wrData;			// write data
	
	reg [2:0] rdAddrA;			// A-side read address
	wire [15:0] rdDataA;		// A-side read data
	
	reg [2:0] rdAddrB; 			// B-side read address
	wire [15:0] rdDataB; 		// B-sdie read data

	//regfile8x16a(clk, write, [2:0]wrAddr, [15:0]wrData, [2:0]rdAddrA, [15:0]rdDataA, [2:0]rdAddrB, [15:0]rdDataB)
	regfile8x16a DUT(.clk(clk), .write(write), .wrAddr(wrAddr), .wrData(wrData), .rdAddrA(rdAddrA), .rdDataA(rdDataA), .rdAddrB(rdAddrB), .rdDataB(rdDataB));
	
	//testing modules and tasks
	
	/*
	the testfile performs several edge case tests to verify the tenuous cases of the regfile, and then performs 2000 random register operations
	to check at least part of the possible cases. this is approached by three tasks, one to operate each section of the register file. these are accompanied by a
	verification task, which ensure the DUT is synced with a local copy of the regfile. 
	
	each DUT test task/function will:
	
	- perform an operation on the register file,
	
	- mirror the operation on the check register file,
	
	- ensure the check register file operation was applied,
	
	- recall the value of the register file,
	
	- check that the register file and the check register file agree.
	
	
	checkRF:
	this task emulates a register file by manipulating our own copy of an equivalent register file. it can be read to or written from in the same manner as the register file. its goal is to mirror all
	operations done on the DUT RF, and then check to ensure the DUT register file yields the same results.
	
	readA, readB, readBoth:
	takes an input address and attempts to read it against the register file. this is simultaneously read from the check register file and compared.
	if both are equal, it reports a success. if both are mismatching, it records an error and prints a message. This can check values for a single register A or B, or both in one clock.
	
	write:
	takes a register address and data, and attempts to write to the register file. this action is mirrored in the check register file, and then both are read
	from the A and B registers. if all three match, it reports a success and continues. if not, it records an error and prints a message.
	
	clk:
	a helper function. rather than manually operating the clock within tasks, this instead automatically increments the clock by one cycle to reduce clutter.

	checkRegfile:
	8 registers, each 16-bit. this copy will mirror the state of the regfile for error checking purposes. since the register file DUT is persistent
	across all tests, we can employ a further measure of validation by demanding consistency across all tests done sequentially.
	
	TEST_PASS, TEST_FAIL
	the pass/fail ratio of specific tests, outide of functions.
	
	NUM_OF_FAILS, NUM_OF_PASSES:
	the total number of fails/passes within the code itself across the whole testbench function. each assertion increments one or the other.
	these fails/passes are individual operations on the register file, not test results.
	
	NUM_RAND:
	the random access loops will run this many times.
	*/
	
	logic [15:0] checkRegfile [0:7];
	int TEST_PASS = 0;
	int TEST_FAIL = 0;
	int NUM_OF_FAILS = 0;
	int NUM_OF_PASS = 0;
	int NUM_RAND = 2000;
	
	task automatic clkCycle;
		begin
			clk = 1'b0;
			#1;
			clk = 1'b1;
			#1;
		end
	endtask
	
	
	task checkRF;
		input write;						//write HIGH line to control whether the register is to be written to or read from
		input [2:0]checkRegAddrA;			//the addresses of the register we want to check
		input [2:0]checkRegAddrB;
		input [15:0]checkRegWriteData;		//the input data to be written
		input [2:0]checkRegWriteAddr;		//the input address for the write register
		output logic [15:0]checkRegDataA;	//the return data of the register we specify
		output logic [15:0]checkRegDataB;
		
		begin
			
			if(write) begin														//if the write line is high,we write the data into the check register file
				//$display("writing check register %b to %h", checkRegWriteAddr, checkRegWriteData);
				checkRegfile[checkRegWriteAddr] = checkRegWriteData;			//we use nonblocking assignments here, so that the registers will always be checked after being potentially set.
				checkRegDataA <= 16'b0;//checkRegfile[checkRegAddrA];  			//the RF sets outputs to 0 to block race conditions, so these options can be just uncommented to 
				checkRegDataB <= 16'b0;//checkRegfile[checkRegAddrB];			//re-emulate that behavior
				//$display("reading check register A from %b: %h, and register B from %b: %h", checkRegAddrA, checkRegDataA, checkRegAddrB, checkRegDataB);
			end else begin
			
			checkRegDataA <= checkRegfile[checkRegAddrA];  						//we set the output register value to the appropriate check regfile address.
			checkRegDataB <= checkRegfile[checkRegAddrB]; 						//this is done regardless of the operation, so we can see the data we wrote in both cases.
			//$display("reading check register A from %b: %h, and register B from %b: %h", checkRegAddrA, checkRegDataA, checkRegAddrB, checkRegDataB);
			end
			/*
			now, we verify that the DUT mirrors our check register by performing two reads from register A and register B, 
			*/
			
			write = 1'b0;														//set the write line low for a read
			rdAddrA = checkRegAddrA;
			rdAddrB = checkRegAddrB;											//set the register file to display check registers A and B
			
			clkCycle();															//wait one clock cycle for the changes to propogate through
			
			
			/*
			both registers A and B will be checked against the check register file here
			*/
			
			//$display("time %d check A: %h, check B: %h, reg A: %h, reg B: %h", $realtime,checkRegDataA,checkRegDataB,rdDataA,rdDataB);
			assert (checkRegDataA === rdDataA) begin								//we assert that the check register and our output return the same data
																					//we report the value updated along with the expected value from the check register
			end else begin
																					//or we display an error and increment the number of fails
				$display($realtime,,,, "ERROR: check register value (", checkRegDataA, ") did not match with DUT register A (", rdDataA);
			end
			
			
			assert (checkRegDataB === rdDataB) begin								//we assert that the check register and our output return the same data
																					//we report the value updated along with the expected value from the check register
			end else begin
																					//or we display an error and increment the number of fails
				$display($realtime,,,, "ERROR: check register value(", checkRegDataB, ") did not match with DUT register B (", rdDataB);
			end	
			
			if(checkRegDataA === rdDataA && checkRegDataB === rdDataB)NUM_OF_PASS++;//we verify if both of the values of the registers match expected
				else NUM_OF_FAILS++;												//and then we increment the appropriate ticker
			
		end
		
	endtask

	/*
	all of the below functions use the same basis in checkRF, but are differentiated from each other to assist in test case clarity.
	*/

	task readA;
		input writeTest;
		input [2:0]rdAddrATest;
		input [15:0]writeTestData;
		input [2:0]writeTestAddr;

		output logic [15:0]testRegA; //we create buckets for register values A and B to go into so the task works
		logic [15:0]testRegB;
		
		write = writeTest;				//set write line as we want
		rdAddrA = rdAddrATest;			//define address to R/W
		rdAddrB = 3'b000;
		wrAddr = writeTestAddr;
		wrData = writeTestData;
		
		checkRF(writeTest, rdAddrATest, 3'b000, writeTestData, writeTestAddr, testRegA, testRegB);	//ensure the changes took properly
		
	endtask
	
	
	task readB;
		input writeTest;
		input [2:0]rdAddrBTest;
		input [15:0]writeTestData;
		input [2:0]writeTestAddr;
		
		output logic [15:0]testRegB; //we create buckets for register values A and B to go into so the task works
		logic [15:0]testRegA;
		
		write = writeTest;				//set write line as we want
		rdAddrB = rdAddrBTest;			//define address to R/W
		rdAddrA = 3'b000;
		wrAddr = writeTestAddr;
		wrData = writeTestData;

		
		checkRF(writeTest, 3'b000, rdAddrBTest, writeTestData, writeTestAddr, testRegA, testRegB); //ensure the changes took properly

	endtask
	
	
	task readBoth;
		input writeTest;
		input [2:0]rdAddrATest;
		input [2:0]rdAddrBTest;
		input [15:0]writeTestData;
		input [2:0]writeTestAddr;
		
		output logic [15:0]testRegA, testRegB; //we create buckets for register values A and B to go into so the task works
		
		
		write = writeTest;				//set write line as we want
		rdAddrA = rdAddrATest;			//define addresses to R/W
		rdAddrB = rdAddrBTest;
		wrAddr = writeTestAddr;
		wrData = writeTestData;		

		checkRF(writeTest, rdAddrATest, rdAddrBTest, writeTestData, writeTestAddr, testRegA, testRegB);	//ensure the changes took properly

	endtask
	
	
	task writeReg;
		input writeTest;				//or test write enable line functionality or whatever
		input [2:0]rdAddrATest;			//I'm keeping all of the possible inputs so that we can
		input [2:0]rdAddrBTest;			//test for leakthrough on any output
		input [15:0]writeTestData;
		input [2:0]writeTestAddr;
		
		logic [15:0]testRegA, testRegB; //we create buckets for register values A and B to go into so the task works
		
		
		write = writeTest;				//set write line as we want
		rdAddrA = rdAddrATest;			//define addresses to R/W
		rdAddrB = rdAddrBTest;			
		wrAddr = writeTestAddr;
		wrData = writeTestData;

		checkRF(writeTest, rdAddrATest, rdAddrBTest, writeTestData, writeTestAddr, testRegA, testRegB);	//ensure the changes took properly		

	endtask
	
	/*
	now we can begin the test cases. i'm just going to put a few example ones in there, but
	there is a framework for more of them if we choose to add them.
	*/
	
	initial begin
		

		//writing and reading to all of the registers 
		
		/*
		we write to all of the registers and read back from them, to make sure they're all working.
		this test writes the index of the register into said register, and reads it back.
		*/
		logic [15:0] testRegA, testRegB;
		for(int i = 0; i < 3'b111; i++) begin
			writeReg(1'b1, 3'h0, 3'h0, i, i);							//write our selected register to its index
			readBoth(1'b0, i, i, 16'h0, i, testRegA, testRegB);	//read from said register into the test buckets
			assert(testRegA === i && testRegB === i)TEST_PASS++;				//assert that both outputs read the same as the index
				else begin TEST_FAIL++;
				$display("read/write test fail %d, %d and %d!", testRegA, testRegB, i);
				end
		end
		
		
		//trying to write to the registers with the write line low
		
		/*
		here, we check if the write line is working right. the for loop tests each register in
		the RF by writing it to 0 with the write line high, then trying to write another
		value to it with the write line low. if this worked right, reading the register again will 
		yield the first written value, as the second one wasn't actually written due to write lock.
		*/
		
		$display("Checking write-lock functionality...");
		for(int i = 0; i < 3'b111; i++) begin							//traverse the arrays
			writeReg(1'b1, 3'h0, 3'h0, 16'h0000, i);					//write our selected register to 0
			writeReg(1'b0, 3'h0, 3'h0, 16'hFFFF, i);					//write our selected register to 1s, with the write line low
			readBoth(1'b0, 3'h0, 3'h0, 16'h0, i, testRegA, testRegB);	//read the register, and see if out write lock worked.
			assert(testRegA === 16'h0000 && testRegB === 16'h0000)TEST_PASS++;		//assert that both registers match the prediction
				else begin TEST_FAIL++;
				$display("write-lock test fail!");
				end
		end
		
		
		//trying to read from the registers while the write line is high
		
		/*
		a characteristic of our register file is that when the write line is high, the output
		lines do not get updated with the requested values. we can check this by setting our 
		output lines to a known value, then writing the register under test to a different
		value, and trying to read it. if the output doesn't update, our write line is 
		working as intended.
		*/
		
		$display("Checking read-lock functionality...");
		for(int i = 0; i < 3'b111; i++) begin							//traverse the arrays
			writeReg(1'b1, 3'h0, 3'h0, 16'h0000, i);					//write our selected register to 0
			testRegA <= 16'b0;											//set the buckets to a known value 0
			testRegB <= 16'b0;
			writeReg(1'b1, 3'h0, 3'h0, 16'hFFFF, i);					//write our selected register to 1s, with the write line high
			readBoth(1'b1, i, i, 16'h0, i, testRegA, testRegB);	//read the register with its write line high, and check if the buckets changed
			assert(testRegA === 16'h0000 && testRegB === 16'h0000)TEST_PASS++;		//assert that both registers match the initial blank values we set them to
				else begin TEST_FAIL++;
				$display("read-lock test fail!");
				end
		end
		
		//reading two different values from the RF, on A and B
		
		/*
		another function we can test is the register file's ability to
		fill both outputs with two different register values. this code traverses 
		each register and asks for one output to output the register's value.
		the other register is set to the next value, 
		or if the value is the end of the register, a rollover to the first register.
		*/
		
		$display("checking R/W on output registers A and B individually...");
		for(int i = 0; i < 3'b111; i++) begin
			writeReg(1'b1, 3'h0, 3'h0, 16'hEEEE, i);											//we set our test register to a value we know
			writeReg(1'b1, 3'h0, 3'h0, 16'hBBBB, (i == 3'b111)?(3'b000):(i + 1));					//and we set our second register, i + 1 with rollover
			readBoth(1'b0, i, (i == 3'b111)?(3'b000):(i + 1), 16'b0, 3'h0, testRegA, testRegB);	//then we check the values of both at the same time
			assert(testRegA === 16'hEEEE && testRegB === 16'hBBBB)TEST_PASS++;					//assert both equal our requested test values.
				else begin TEST_FAIL++;
				$display("individual output test fail!");
				end
		end
		
		//writing to the RF: checkerboard 0101 and 1010
		
		/*
		a good test of the register data is to use the checkerboard pattern.
		so, this test just writes checkerboard patterns to a register, checks it read back properly,
		then checks the NOT of the checkerboard pattern.
		*/
		
		$display("checking R/W with checkerboard pattern...");					//display announcement message
		for(int i = 0; i < 3'b111; i++) begin									//loop through all registers
			writeReg(1'b1, 3'h0, 3'h0, 16'h5555, i);							//write checkerboard pattern to registers
			readBoth(1'b0, i, i, 16'h0, i, testRegA, testRegB);					//read register back
			assert(testRegA === 16'h5555 && testRegB === 16'h5555)TEST_PASS++;	//assert both regs read correctly
				else begin TEST_FAIL++;											//increment result tallies
				$display("checkerboard test fail!");							//error notif message
				end	
			
			
			writeReg(1'b1, 3'h0, 3'h0, 16'hAAAA, i);							//write NOT of previous checkerboard
			readBoth(1'b0, i, i, 16'h0, i, testRegA, testRegB);					//read register again
			assert(testRegA === 16'hAAAA && testRegB === 16'hAAAA)TEST_PASS++;	//assert registers match expected values
				else begin TEST_FAIL++;											//increment result tallies
				$display("checkerboard test 2 fail!");							//error notif message
				end
		end
		
		//random I/O operations
		
		/*
		the final segment of the program does n't explicitly check edge cases anymore, and instead tests 
		randomized cases of input or output.
		*/
		
		$display("performing %5d random tests...", NUM_RAND);
		for(int i = 0; i < NUM_RAND; i++) begin
			//checkRF does all the verification for us, so we don't need to do anything with the testRegA and testRegB buckets
			readBoth($urandom_range(0,1'b1), $urandom_range(0,3'b111), $urandom_range(0,3'b111),$urandom_range(0,16'hFFFF), $urandom_range(0,3'b111), testRegA, testRegB);
		end
		
		//display the number of internal access fails/passes, and test results
		$display("number of random loops passed: %4d\nnumber of successful register file accesses: %4d\nnumber of failures: %4d", NUM_RAND, NUM_OF_PASS, NUM_OF_FAILS);
		$display("%3d tests passed, %3d tests failed", TEST_PASS, TEST_FAIL);
	end

endmodule