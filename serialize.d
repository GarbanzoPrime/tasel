/* Copyright 2013, Garbanzo Prime

    This file is part of tasel.
    tasel is subject to the license specified in LICENSE.txt
*/
 
module tasel.serialize ;

import std.exception ;
import std.traits;
import std.stdio;
import std.range;
import core.thread ;
import std.functional ;

//serialize
/**
Lazily serializes the passed data as a series of ubyte[].
*/
auto serialize(T)( T data ) {
	return SerializerRange( data ) ;
}

//deserialize
/**
Deserializes the passed range as an instance of T. It is assumed that T is the same type that was passed to serialize.

The passed range can be:
a) a range of ubyte[]
b) a range of ubyte
*/
template deserialize(T)
{
	T deserialize(R)( R range ) {
		T result ;
		deserializeImpl(result,range) ;
		return result ;
	}
}



template isSerializableAsValue(T) {
	static if( is( T == struct ) ) {
		enum isSerializableAsValue = __traits( isPOD , T ) && !hasIndirections!T ;
	}
	else static if( is( T == class ) ) { 
		enum isSerializableAsValue = false ;
	}
	else static if( isAssociativeArray!(T) ) {
		enum isSerializableAsValue = false ;
	}
	else {
		enum isSerializableAsValue = __traits( isPOD , T ) ;
	}
}

template isSerializableAsValue(T : T[] ) {
	enum isSerializableAsValue = __traits( isPOD , T ) && !hasIndirections!T ;
}

unittest {
	struct passes {
		int a ;
		float b ;
	}

	struct passesToo {
		passes a ;
		float b ;
	}

	struct alsoPasses {
		passes a ;
		float b ;
	}

	struct Fails {
		~this() {}
		float b ;
	}

	class DoesNotPass {
		int a ;
		float b ;
	}

	static assert( isSerializableAsValue!int ) ;
	static assert( isSerializableAsValue!double ) ;
	static assert( isSerializableAsValue!int ) ;
	static assert( isSerializableAsValue!(int[]) ) ;
	static assert( !isSerializableAsValue!(int[][]) ) ;
	static assert( isSerializableAsValue!passes ) ;
	static assert( isSerializableAsValue!passesToo ) ;
	static assert( isSerializableAsValue!alsoPasses ) ;
	static assert( isSerializableAsValue!(passes[]) ) ;
	static assert( isSerializableAsValue!(passesToo[]) ) ;
	static assert( isSerializableAsValue!(alsoPasses[]) ) ;
	static assert( !isSerializableAsValue!(DoesNotPass) ) ;
	static assert( !isSerializableAsValue!(Fails) ) ;
}

private
{
	struct SerializerRange {
		this(T)( T data ) {
			alias curry!(advance!T,data ) FiberHead ;
			_fiber = new Fiber( &FiberHead ) ;

			_fiber.call() ;
		}

		@property bool empty() {
			return _fiber.state == Fiber.State.TERM ;
		}

		void popFront() { 
			_fiber.call() ;
		}

		@property ubyte[] front() { 
			return _front ; 
		}

	private:
		Fiber _fiber ;
		__gshared ubyte[] _front ;


		//simple value
		void advance(T)( T data ) if( !isArray!T && isSerializableAsValue!T ) {
			_front = cast (ubyte[])(&data)[0..1] ;
			Fiber.yield() ;
		}

		//array of serializables
		void advance(T)( T data ) if( isArray!T && isSerializableAsValue!T ) {
			auto data_length = data.length ;
			advance(data_length) ;

			_front = cast (ubyte[])data ;
			Fiber.yield() ;
		}

		//array of non-serializable
		void advance(T)( T data ) if( isArray!T && !isSerializableAsValue!T ) {
			auto data_length = data.length ;
			advance( data_length ) ;


			if( data.length > 0 ) {
				foreach( val ; data ) {
					advance( val ) ;
				}
			}
		}

		//non-serializable struct
		void advance(T)( T data ) if( is( T == struct ) && !isSerializableAsValue!T ) {
			foreach (val ; data.tupleof ) {
				advance( val ) ;
			}
		}

		//associative array
		void advance(T)( T data ) if( isAssociativeArray!(T) ) {

			auto data_length = data.length ;
			advance( data_length ) ;

			foreach( key ; data.keys ) {
				advance( key ) ;
				advance( data[key]) ;
			}
		}	 
	}

	void deserializeImpl(T,R)( ref T target , ref R range ) if( !isArray!T && isSerializableAsValue!T ) {
		ubyte[] bytes ;
		static if(hasSlicing!R) {
			//if R slices, then it bloody well have enough data to fill T
			bytes = range[0 .. T.sizeof];

			target = *cast(T*)bytes.ptr ;
			range = range.popFrontN(T.sizeof);
		}
		else static if( is( ElementEncodingType!R == ubyte[] ) ) {
			bytes = range.front ;
			target = *cast(T*)bytes.ptr ;
			range.popFront() ;
		}
		else
		{
			//assuming range of byte
			bytes.length = T.sizeof;
			foreach(ref e; bytes) {
	            e = range.front;
	            range.popFront();
	        }
	        target = *cast(T*)bytes.ptr ;
		}
	}

	void deserializeImpl(T,R)( ref T target , ref R range ) if( isArray!T && isSerializableAsValue!T ) {
		alias ElementEncodingType!T ElemType ;
		size_t data_len ;
		deserializeImpl(data_len,range) ;

		data_len *= ElemType.sizeof ;

		ubyte[] bytes ;
		static if(hasSlicing!R) {
			//if R slices, then it bloody well have enough data to fill T
			bytes = range[0 .. data_len];
			range = range.popFrontN(data_len);
		}
		else static if( is( ElementEncodingType!R == ubyte[] ) ) {
			bytes = range.front[0..data_len] ;
			range.popFront() ;
		}
		else
		{
			//assuming range of byte
			bytes.length = data_len;
			foreach(ref e; bytes) {
	            e = range.front;
	            range.popFront();
	        }
		}

		target = cast (T)bytes ;
	}

	void deserializeImpl(T,R)( ref T target , ref R range ) if( isArray!T && !isSerializableAsValue!T ) {
		alias ElementEncodingType!T ElemType ;

		size_t array_len ;
		deserializeImpl(array_len,range) ;
		target.length = array_len ;

		foreach(ref e; target) {

	    	deserializeImpl( e, range ) ;
	    }
	}

	void deserializeImpl(T,R)( ref T target , ref R range ) if( is( T == struct ) && !isSerializableAsValue!T ) {
		
		foreach (ref val ; target.tupleof ) {
			deserializeImpl( val , range ) ;
		}

	}

	void deserializeImpl(T,R)( ref T target , ref R range ) if( isAssociativeArray!(T) ) {
		size_t array_len ;

		deserializeImpl(array_len,range) ;

		foreach( i ; 0..array_len) {
			KeyType!(T) key ;
			ValueType!(T) val ;

			deserializeImpl( key , range ) ;
			deserializeImpl( val , range ) ;

			target[key] = val ;
		}
	}
}