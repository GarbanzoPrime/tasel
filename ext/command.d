/* Copyright 2013, Garbanzo Prime

    This file is part of tasel.
    tasel is subject to the license specified in LICENSE.txt
*/
 
module tasel.ext.command ;

import tasel.tasel ;
import std.functional ;
import std.stdio ;
import std.process ;
import std.string ;
/**
	a simple wrapper around a system call. It is assumed that the command has no extra dependencies beyond the
	provided input data.
*/
class CommandTask(fun...) : UserTask {
	
	alias unaryFun!fun _fun;

	this( Resource input , Resource output ) {
		super( input , output ) ;
	}

	this( Resource input , Resource[] output ) {
		super( input , output ) ;
	}

	this( Resource[] input , Resource output ) {
		super( input , output ) ;
	}

	this( Resource[] input , Resource[] output ) {
		super( input , output ) ;
	}

	override TaskId getId() immutable {
		auto result = super.getId() ;
		foreach( str ; _fun(this) ) {
			result ~= str ;
		}

		return result ;
	}

	override bool run() immutable {
		auto commandLine = _fun(this) ;
		
		writeln( commandLine ) ;
		auto pid = spawnProcess( commandLine ) ;

		return pid.wait() == 0 ;
	}
}


class ShellTask(fun...) : UserTask {
	
	alias unaryFun!fun _fun;

	this( Resource input , Resource output ) {
		super( input , output ) ;
	}

	this( Resource input , Resource[] output ) {
		super( input , output ) ;
	}

	this( Resource[] input , Resource output ) {
		super( input , output ) ;
	}

	this( Resource[] input , Resource[] output ) {
		super( input , output ) ;
	}

	override TaskId getId() immutable {
		auto result = super.getId() ;

		result ~= _fun(this) ;

		return result ;
	}

	override bool run() immutable {
		auto commandLine = _fun(this) ;
		
		writeln( commandLine ) ;
		auto pid = spawnShell( commandLine ) ;

		return pid.wait() == 0 ;
	}
}