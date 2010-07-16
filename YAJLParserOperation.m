//
//  YAJLParserOperation.m
//  Pulse News
//
//  Created by Ankit Gupta on 7/2/10.
//  Copyright 2010 Stanford University. All rights reserved.
//

#import "YAJLParserOperation.h"

@implementation YAJLParserOperation

@synthesize document_, error_;

#pragma mark -
#pragma mark Initialization & Memory Management

- (id)init
{
	return [self initWithURL:nil];
}

- (id)initWithURL:(NSURL *)url
{
	NSParameterAssert( url );
	if( (self = [super init]) ) {
		connectionURL_ = [url copy];
		YAJLDocument* document = [[YAJLDocument alloc] init];
		self.document_ = document;
		[document release];
	}
	return self;
}

- (void)dealloc
{
	if( connection_ ) { [connection_ cancel]; [connection_ release]; connection_ = nil; }
	[connectionURL_ release];
	[error_ release];
	[document_ release];
	document_ = nil;
	[super dealloc];
}

#pragma mark -
#pragma mark Start & Utility Methods

// This method is just for convenience. It cancels the URL connection if it
// still exists and finishes up the operation.
- (void)done
{
	if( connection_ ) {
		[connection_ cancel];
		[connection_ release];
		[connectionURL_ release];
		connectionURL_ = nil;
		connection_ = nil;
	}
	
	// Alert anyone that we are finished
	[self willChangeValueForKey:@"isExecuting"];
	[self willChangeValueForKey:@"isFinished"];
	executing_ = NO;
	finished_  = YES;
	[self didChangeValueForKey:@"isFinished"];
	[self didChangeValueForKey:@"isExecuting"];
}
- (void)start
{
	//iOS 4 bug fix
	if (![NSThread isMainThread])
	{
		[self performSelectorOnMainThread:@selector(start)
							   withObject:nil waitUntilDone:NO];
		return;
	}

	// Ensure this operation is not being restarted and that it has not been cancelled
	if( finished_ || [self isCancelled] ) { [self done]; return; }
	
	
	NSLog(@"Started Parsing %@", [connectionURL_ description]);
	// From this point on, the operation is officially executing--remember, isExecuting
	// needs to be KVO compliant!
	[self willChangeValueForKey:@"isExecuting"];
	executing_ = YES;
	[self didChangeValueForKey:@"isExecuting"];
	
	// Create the NSURLConnection--this could have been done in init, but we delayed
	// until no in case the operation was never enqueued or was cancelled before starting
	connection_ = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:connectionURL_]
												  delegate:self];
}

#pragma mark -
#pragma mark Overrides

- (BOOL)isConcurrent
{
	return YES;
}

- (BOOL)isExecuting
{
	return executing_;
}

- (BOOL)isFinished
{
	return finished_;
}

- (void)cancel
{
	[self done];
	[super cancel];
}

#pragma mark -
#pragma mark Delegate Methods for NSURLConnection

// For this example, we only handle the standard delegate call-backs

// The connection failed
- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
	error_ = [error retain];
	[self done];
}

// The connection received more data
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	if([self isCancelled]) {
		[self done];
	}
	NSError *error = nil;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	YAJLParserStatus status = [document_ parse:data error:&error];
	[pool release];
	if (status == YAJLParserStatusOK) {
		NSLog(@"Parser OK");
		[self done];
	}
	
	
}

// Initial response
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	if([self isCancelled]) {
		[self done];
	}
	
	NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
	NSInteger statusCode = [httpResponse statusCode];
	if( statusCode == 200 ) {
	} else {
		NSString* statusError  = [NSString stringWithFormat:NSLocalizedString(@"HTTP Error: %ld", nil), statusCode];
		NSDictionary* userInfo = [NSDictionary dictionaryWithObject:statusError forKey:NSLocalizedDescriptionKey];
		error_ = [[NSError alloc] initWithDomain:@"ExampleOperationDomain"
											code:statusCode
										userInfo:userInfo];
		[self done];
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[self done];
}

@end
