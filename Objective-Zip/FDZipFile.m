//
//  ZipFile.m
//  Objective-Zip v. 0.8.3
//
//  Created by Gianluca Bertani on 25/12/09.
//  Copyright 2009-10 Flying Dolphin Studio. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without 
//  modification, are permitted provided that the following conditions 
//  are met:
//
//  * Redistributions of source code must retain the above copyright notice, 
//    this list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, 
//    this list of conditions and the following disclaimer in the documentation 
//    and/or other materials provided with the distribution.
//  * Neither the name of Gianluca Bertani nor the names of its contributors 
//    may be used to endorse or promote products derived from this software 
//    without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
//  POSSIBILITY OF SUCH DAMAGE.
//

#import "FDZipFile.h"
#import "FDZipException.h"
#import "FDZipReadStream.h"
#import "FDZipWriteStream.h"
#import "FDFileInZipInfo.h"

#define FILE_IN_ZIP_MAX_NAME_LENGTH (256)


@implementation FDZipFile


- (id) initWithFileName:(NSString *)fileName mode:(FDZipFileMode)mode {
	if (self= [super init]) {
		_fileName= fileName;
		_mode= mode;
		
		switch (mode) {
			case FDZipFileModeUnzip:
				_unzFile= unzOpen64([_fileName cStringUsingEncoding:NSUTF8StringEncoding]);
				if (_unzFile == NULL) {
					NSString *reason= [NSString stringWithFormat:@"Can't open '%@'", _fileName];
					@throw [[FDZipException alloc] initWithReason:reason];
				}
				break;
				
			case FDZipFileModeCreate:
				_zipFile= zipOpen64([_fileName cStringUsingEncoding:NSUTF8StringEncoding], APPEND_STATUS_CREATE);
				if (_zipFile == NULL) {
					NSString *reason= [NSString stringWithFormat:@"Can't open '%@'", _fileName];
					@throw [[FDZipException alloc] initWithReason:reason];
				}
				break;
				
			case FDZipFileModeAppend:
				_zipFile= zipOpen64([_fileName cStringUsingEncoding:NSUTF8StringEncoding], APPEND_STATUS_ADDINZIP);
				if (_zipFile == NULL) {
					NSString *reason= [NSString stringWithFormat:@"Can't open '%@'", _fileName];
					@throw [[FDZipException alloc] initWithReason:reason];
				}
				break;
				
			default: {
				NSString *reason= [NSString stringWithFormat:@"Unknown mode %d", _mode];
				@throw [[FDZipException alloc] initWithReason:reason];
			}
		}
	}
	
	return self;
}


- (FDZipWriteStream *) writeFileInZipWithName:(NSString *)fileNameInZip compressionLevel:(FDZipCompressionLevel)compressionLevel {
	if (_mode == FDZipFileModeUnzip) {
		NSString *reason= [NSString stringWithFormat:@"Operation not permitted with Unzip mode"];
		@throw [[FDZipException alloc] initWithReason:reason];
	}
	
	NSDate *now= [NSDate date];
	NSCalendar *calendar= [NSCalendar currentCalendar];
	NSDateComponents *date= [calendar components:(NSSecondCalendarUnit | NSMinuteCalendarUnit | NSHourCalendarUnit | NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit) fromDate:now];	
	zip_fileinfo zi;
	zi.tmz_date.tm_sec= [date second];
	zi.tmz_date.tm_min= [date minute];
	zi.tmz_date.tm_hour= [date hour];
	zi.tmz_date.tm_mday= [date day];
	zi.tmz_date.tm_mon= [date month] -1;
	zi.tmz_date.tm_year= [date year];
	zi.internal_fa= 0;
	zi.external_fa= 0;
	zi.dosDate= 0;
	
	int err= zipOpenNewFileInZip3_64(
									 _zipFile,
									 [fileNameInZip cStringUsingEncoding:NSUTF8StringEncoding],
									 &zi,
									 NULL, 0, NULL, 0, NULL,
									 (compressionLevel != FDZipCompressionLevelNone) ? Z_DEFLATED : 0,
									 compressionLevel, 0,
									 -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY,
									 NULL, 0, 1);
	if (err != ZIP_OK) {
		NSString *reason= [NSString stringWithFormat:@"Error opening '%@' in zipfile", fileNameInZip];
		@throw [[FDZipException alloc] initWithError:err reason:reason];
	}
	
	return [[FDZipWriteStream alloc] initWithZipFileStruct:_zipFile fileNameInZip:fileNameInZip];
}

- (FDZipWriteStream *) writeFileInZipWithName:(NSString *)fileNameInZip fileDate:(NSDate *)fileDate compressionLevel:(FDZipCompressionLevel)compressionLevel {
	if (_mode == FDZipFileModeUnzip) {
		NSString *reason= [NSString stringWithFormat:@"Operation not permitted with Unzip mode"];
		@throw [[FDZipException alloc] initWithReason:reason];
	}
	
	NSCalendar *calendar= [NSCalendar currentCalendar];
	NSDateComponents *date= [calendar components:(NSSecondCalendarUnit | NSMinuteCalendarUnit | NSHourCalendarUnit | NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit) fromDate:fileDate];	
	zip_fileinfo zi;
	zi.tmz_date.tm_sec= [date second];
	zi.tmz_date.tm_min= [date minute];
	zi.tmz_date.tm_hour= [date hour];
	zi.tmz_date.tm_mday= [date day];
	zi.tmz_date.tm_mon= [date month] -1;
	zi.tmz_date.tm_year= [date year];
	zi.internal_fa= 0;
	zi.external_fa= 0;
	zi.dosDate= 0;
	
	int err= zipOpenNewFileInZip3_64(
									 _zipFile,
									 [fileNameInZip cStringUsingEncoding:NSUTF8StringEncoding],
									 &zi,
									 NULL, 0, NULL, 0, NULL,
									 (compressionLevel != FDZipCompressionLevelNone) ? Z_DEFLATED : 0,
									 compressionLevel, 0,
									 -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY,
									 NULL, 0, 1);
	if (err != ZIP_OK) {
		NSString *reason= [NSString stringWithFormat:@"Error opening '%@' in zipfile", fileNameInZip];
		@throw [[FDZipException alloc] initWithError:err reason:reason];
	}
	
	return [[FDZipWriteStream alloc] initWithZipFileStruct:_zipFile fileNameInZip:fileNameInZip];
}

- (FDZipWriteStream *) writeFileInZipWithName:(NSString *)fileNameInZip fileDate:(NSDate *)fileDate compressionLevel:(FDZipCompressionLevel)compressionLevel password:(NSString *)password crc32:(NSUInteger)crc32 {
	if (_mode == FDZipFileModeUnzip) {
		NSString *reason= [NSString stringWithFormat:@"Operation not permitted with Unzip mode"];
		@throw [[FDZipException alloc] initWithReason:reason];
	}
	
	NSCalendar *calendar= [NSCalendar currentCalendar];
	NSDateComponents *date= [calendar components:(NSSecondCalendarUnit | NSMinuteCalendarUnit | NSHourCalendarUnit | NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit) fromDate:fileDate];	
	zip_fileinfo zi;
	zi.tmz_date.tm_sec= [date second];
	zi.tmz_date.tm_min= [date minute];
	zi.tmz_date.tm_hour= [date hour];
	zi.tmz_date.tm_mday= [date day];
	zi.tmz_date.tm_mon= [date month] -1;
	zi.tmz_date.tm_year= [date year];
	zi.internal_fa= 0;
	zi.external_fa= 0;
	zi.dosDate= 0;
	
	int err= zipOpenNewFileInZip3_64(
									 _zipFile,
									 [fileNameInZip cStringUsingEncoding:NSUTF8StringEncoding],
									 &zi,
									 NULL, 0, NULL, 0, NULL,
									 (compressionLevel != FDZipCompressionLevelNone) ? Z_DEFLATED : 0,
									 compressionLevel, 0,
									 -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY,
									 [password cStringUsingEncoding:NSUTF8StringEncoding], crc32, 1);
	if (err != ZIP_OK) {
		NSString *reason= [NSString stringWithFormat:@"Error opening '%@' in zipfile", fileNameInZip];
		@throw [[FDZipException alloc] initWithError:err reason:reason];
	}
	
	return [[FDZipWriteStream alloc] initWithZipFileStruct:_zipFile fileNameInZip:fileNameInZip];
}

- (NSString*) fileName {
	return _fileName;
}

- (NSUInteger) numFilesInZip {
	if (_mode != FDZipFileModeUnzip) {
		NSString *reason= [NSString stringWithFormat:@"Operation not permitted without Unzip mode"];
		@throw [[FDZipException alloc] initWithReason:reason];
	}
	
	unz_global_info64 gi;
	int err= unzGetGlobalInfo64(_unzFile, &gi);
	if (err != UNZ_OK) {
		NSString *reason= [NSString stringWithFormat:@"Error getting global info in '%@'", _fileName];
		@throw [[FDZipException alloc] initWithError:err reason:reason];
	}
	
	return gi.number_entry;
}

- (NSArray *) listFileInZipInfos {
	int num= [self numFilesInZip];
	if (num < 1)
		return [[NSArray alloc] init];
	
	NSMutableArray *files= [[NSMutableArray alloc] initWithCapacity:num];

	[self goToFirstFileInZip];
	for (int i= 0; i < num; i++) {
		FDFileInZipInfo *info= [self getCurrentFileInZipInfo];
		[files addObject:info];

		if ((i +1) < num)
			[self goToNextFileInZip];
	}

	return files;
}

- (void) goToFirstFileInZip {
	if (_mode != FDZipFileModeUnzip) {
		NSString *reason= [NSString stringWithFormat:@"Operation not permitted without Unzip mode"];
		@throw [[FDZipException alloc] initWithReason:reason];
	}
	
	int err= unzGoToFirstFile(_unzFile);
	if (err != UNZ_OK) {
		NSString *reason= [NSString stringWithFormat:@"Error going to first file in zip in '%@'", _fileName];
		@throw [[FDZipException alloc] initWithError:err reason:reason];
	}
}

- (BOOL) goToNextFileInZip {
	if (_mode != FDZipFileModeUnzip) {
		NSString *reason= [NSString stringWithFormat:@"Operation not permitted without Unzip mode"];
		@throw [[FDZipException alloc] initWithReason:reason];
	}
	
	int err= unzGoToNextFile(_unzFile);
	if (err == UNZ_END_OF_LIST_OF_FILE)
		return NO;

	if (err != UNZ_OK) {
		NSString *reason= [NSString stringWithFormat:@"Error going to next file in zip in '%@'", _fileName];
		@throw [[FDZipException alloc] initWithError:err reason:reason];
	}
	
	return YES;
}

- (BOOL) locateFileInZip:(NSString *)fileNameInZip {
	if (_mode != FDZipFileModeUnzip) {
		NSString *reason= [NSString stringWithFormat:@"Operation not permitted without Unzip mode"];
		@throw [[FDZipException alloc] initWithReason:reason];
	}
	
	int err= unzLocateFile(_unzFile, [fileNameInZip cStringUsingEncoding:NSUTF8StringEncoding], NULL);
	if (err == UNZ_END_OF_LIST_OF_FILE)
		return NO;

	if (err != UNZ_OK) {
		NSString *reason= [NSString stringWithFormat:@"Error localting file in zip in '%@'", _fileName];
		@throw [[FDZipException alloc] initWithError:err reason:reason];
	}
	
	return YES;
}

- (FDFileInZipInfo *) getCurrentFileInZipInfo {
	if (_mode != FDZipFileModeUnzip
        ) {
		NSString *reason= [NSString stringWithFormat:@"Operation not permitted without Unzip mode"];
		@throw [[FDZipException alloc] initWithReason:reason];
	}

	char filename_inzip[FILE_IN_ZIP_MAX_NAME_LENGTH];
	unz_file_info64 file_info;
	
	int err= unzGetCurrentFileInfo64(_unzFile, &file_info, filename_inzip, sizeof(filename_inzip), NULL, 0, NULL, 0);
	if (err != UNZ_OK) {
		NSString *reason= [NSString stringWithFormat:@"Error getting current file info in '%@'", _fileName];
		@throw [[FDZipException alloc] initWithError:err reason:reason];
	}
	
	NSString *name= [NSString stringWithCString:filename_inzip encoding:NSUTF8StringEncoding];
	
	FDZipCompressionLevel level= FDZipCompressionLevelNone;
	if (file_info.compression_method != 0) {
		switch ((file_info.flag & 0x6) / 2) {
			case 0:
				level= FDZipCompressionLevelDefault;
				break;
				
			case 1:
				level= FDZipCompressionLevelBest;
				break;
				
			default:
				level= FDZipCompressionLevelFastest;
				break;
		}
	}
	
	BOOL crypted= ((file_info.flag & 1) != 0);
	
	NSDateComponents *components= [[NSDateComponents alloc] init];
	[components setDay:file_info.tmu_date.tm_mday];
	[components setMonth:file_info.tmu_date.tm_mon +1];
	[components setYear:file_info.tmu_date.tm_year];
	[components setHour:file_info.tmu_date.tm_hour];
	[components setMinute:file_info.tmu_date.tm_min];
	[components setSecond:file_info.tmu_date.tm_sec];
	NSCalendar *calendar= [NSCalendar currentCalendar];
	NSDate *date= [calendar dateFromComponents:components];
	
	FDFileInZipInfo *info= [[FDFileInZipInfo alloc] initWithName:name length:file_info.uncompressed_size level:level crypted:crypted size:file_info.compressed_size date:date crc32:file_info.crc];
	return info;
}

- (FDZipReadStream *) readCurrentFileInZip {
	if (_mode !=FDZipFileModeUnzip) {
		NSString *reason= [NSString stringWithFormat:@"Operation not permitted without Unzip mode"];
		@throw [[FDZipException alloc] initWithReason:reason];
	}

	char filename_inzip[FILE_IN_ZIP_MAX_NAME_LENGTH];
	unz_file_info64 file_info;
	
	int err= unzGetCurrentFileInfo64(_unzFile, &file_info, filename_inzip, sizeof(filename_inzip), NULL, 0, NULL, 0);
	if (err != UNZ_OK) {
		NSString *reason= [NSString stringWithFormat:@"Error getting current file info in '%@'", _fileName];
		@throw [[FDZipException alloc] initWithError:err reason:reason];
	}
	
	NSString *fileNameInZip= [NSString stringWithCString:filename_inzip encoding:NSUTF8StringEncoding];
	
	err= unzOpenCurrentFilePassword(_unzFile, NULL);
	if (err != UNZ_OK) {
		NSString *reason= [NSString stringWithFormat:@"Error opening current file in '%@'", _fileName];
		@throw [[FDZipException alloc] initWithError:err reason:reason];
	}
	
	return [[FDZipReadStream alloc] initWithUnzFileStruct:_unzFile fileNameInZip:fileNameInZip];
}

- (FDZipReadStream *) readCurrentFileInZipWithPassword:(NSString *)password {
	if (_mode != FDZipFileModeUnzip) {
		NSString *reason= [NSString stringWithFormat:@"Operation not permitted without Unzip mode"];
		@throw [[FDZipException alloc] initWithReason:reason];
	}
	
	char filename_inzip[FILE_IN_ZIP_MAX_NAME_LENGTH];
	unz_file_info64 file_info;
	
	int err= unzGetCurrentFileInfo64(_unzFile, &file_info, filename_inzip, sizeof(filename_inzip), NULL, 0, NULL, 0);
	if (err != UNZ_OK) {
		NSString *reason= [NSString stringWithFormat:@"Error getting current file info in '%@'", _fileName];
		@throw [[FDZipException alloc] initWithError:err reason:reason];
	}
	
	NSString *fileNameInZip= [NSString stringWithCString:filename_inzip encoding:NSUTF8StringEncoding];

	err= unzOpenCurrentFilePassword(_unzFile, [password cStringUsingEncoding:NSUTF8StringEncoding]);
	if (err != UNZ_OK) {
		NSString *reason= [NSString stringWithFormat:@"Error opening current file in '%@'", _fileName];
		@throw [[FDZipException alloc] initWithError:err reason:reason];
	}
	
	return [[FDZipReadStream alloc] initWithUnzFileStruct:_unzFile fileNameInZip:fileNameInZip];
}

- (void) close {
	switch (_mode) {
		case FDZipFileModeUnzip: {
			int err= unzClose(_unzFile);
			if (err != UNZ_OK) {
				NSString *reason= [NSString stringWithFormat:@"Error closing '%@'", _fileName];
				@throw [[FDZipException alloc] initWithError:err reason:reason];
			}
			break;
		}
			
		case FDZipFileModeCreate: {
			int err= zipClose(_zipFile, NULL);
			if (err != ZIP_OK) {
				NSString *reason= [NSString stringWithFormat:@"Error closing '%@'", _fileName];
				@throw [[FDZipException alloc] initWithError:err reason:reason];
			}
			break;
		}
			
		case FDZipFileModeAppend: {
			int err= zipClose(_zipFile, NULL);
			if (err != ZIP_OK) {
				NSString *reason= [NSString stringWithFormat:@"Error closing '%@'", _fileName];
				@throw [[FDZipException alloc] initWithError:err reason:reason];
			}
			break;
		}

		default: {
			NSString *reason= [NSString stringWithFormat:@"Unknown mode %d", _mode];
			@throw [[FDZipException alloc] initWithReason:reason];
		}
	}
}


@end
