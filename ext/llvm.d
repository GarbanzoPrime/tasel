/* Copyright 2013, Garbanzo Prime

    This file is part of tasel.
    tasel is subject to the license specified in LICENSE.txt
*/

module tasel.ext.llvm ;

import tasel.tasel ;
import std.process ;
import std.string ;
import std.exception ;
import std.stdio ;
import std.algorithm ;
import std.array ;

class ClangToIR : UserTask {
	this( const string src_file , const string result_file , const string[] inFlags = [] ) {
		super( FileRes( src_file ) , FileRes( result_file ) ) ;

		flags = inFlags ;
	}

	const string[] flags ;

	override TaskId getId() immutable {
		string commandLine = super.getId() ~ "clang" ;

		foreach( flag ; flags ) {
			commandLine ~= " " ~ flag ;
		}
			
		return commandLine ;
	}

	override bool run() immutable {
		string commandLine = "clang" ;
		
		foreach( flag ; flags ) {
			commandLine ~= " " ~ flag ;
		}

		commandLine ~= " -emit-llvm -o " ~ outputs[0].name ;
		commandLine ~= " " ~ inputs[0].name ;

		writeln( commandLine ) ;

		return system( commandLine ) == 0 ;
	}
}

class LinkIR : UserTask {
	this( Resource [] inputs , const string output ) {
		super( inputs , FileRes( output ) ) ;	
	}

	override bool run() immutable {
		string commandLine = "llvm-link" ;

		commandLine ~= " -o=" ~ outputs[0].name ;
		
		foreach( file ; inputs ) {
			commandLine ~= " " ~ file.name ;
		}

		writeln( commandLine ) ;

		return system( commandLine ) == 0 ;
	}
}


Resource addLLVMLib( BuildSet tasks , const string[] src , const string lib_path , const string intermediate_path, const string[] compile_flags ) {
	auto actual_compile_flags = compile_flags ~ [ "-c"];
	auto compile_tasks = makeTasks!( e => new ClangToIR( e , intermediate_path ~ e ~ ".ir" , actual_compile_flags ) )( src ) ;

	Resource[] ir_files = map!( e => e.outputs[0] ) ( compile_tasks ).array().dup ;

	tasks ~= compile_tasks ;
	
        auto link_task = new LinkIR( ir_files , lib_path ) ;
	tasks ~= link_task ;	
	return link_task.outputs[0];
}

