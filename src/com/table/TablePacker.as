package com.table
{
	import flash.desktop.NativeApplication;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import flash.utils.Endian;
	
	import mx.controls.Alert;
	
	public class TablePacker
	{
		private var _dir:File;
		
		private var _xlsDataDict:Dictionary;
		
		private var _curCount:int;
		
		private var _totalCount:int;
		
		public function TablePacker()
		{
			_dir = File.applicationDirectory.resolvePath("bytes/");
			_xlsDataDict = new Dictionary();
			_curCount = 0;
			_totalCount = 0;
			ReadBinaryData();
		}
		
		public function ReadBinaryData():void
		{
			var list:Array = _dir.getDirectoryListing();
			_totalCount = list.length;
			for (var i:int = 0; i < list.length; ++i)
			{
				var subfile:File = list[i] as File;
				var loader:URLLoader = new URLLoader();
				loader.dataFormat = URLLoaderDataFormat.BINARY;
				trace(subfile.nativePath);
				loader.load(new URLRequest(subfile.nativePath));
				loader.addEventListener(IOErrorEvent.IO_ERROR,onConfigIO);
				loader.addEventListener(Event.COMPLETE,parseData);	
			}
		}
		
		private function onConfigIO(e:IOErrorEvent):void
		{
			Alert.show("[TablePacker]Can not found xls binfile.");
		}
		
		private function parseData(e:Event):void
		{
			var loader:URLLoader = e.currentTarget as URLLoader;
			loader.removeEventListener(Event.COMPLETE,parseData);
			var bytes:ByteArray = loader.data as ByteArray;
			bytes.endian = Endian.LITTLE_ENDIAN;
			var typeCode:uint = bytes.readUnsignedInt();
			var propLength:int = bytes.readInt();
			var propStr:Array = bytes.readUTFBytes(propLength).split(',');
			var tempData:ByteArray = new ByteArray();
			tempData.endian = Endian.LITTLE_ENDIAN;
			while(bytes.bytesAvailable > 0)
			{
				for (var i:int = 0; i < propStr.length; ++i)
				{
					if (propStr[i] == "int")
					{
						var tempInt:int = bytes.readInt();
						tempData.writeInt(tempInt);
					}
					else if (propStr[i] == "float")
					{
						var tempFloat:Number = bytes.readFloat();
						tempData.writeFloat(tempFloat);
					}
					else
					{
						var len:int = bytes.readInt();
						var tempStr:String = bytes.readUTFBytes(len);
						tempData.writeUTF(tempStr);
					}
				}
			}
			_xlsDataDict[typeCode] = new ByteArray();
			_xlsDataDict[typeCode].endian = Endian.LITTLE_ENDIAN;
			_xlsDataDict[typeCode].writeUnsignedInt(typeCode);
			_xlsDataDict[typeCode].writeInt(tempData.length);
			_xlsDataDict[typeCode].writeBytes(tempData);
			_curCount++;
			if (_curCount >= _totalCount)
			{
				PackAll();
				NativeApplication.nativeApplication.exit();
			}
		}
		
		private function PackAll():void
		{
			var path:String = File.applicationDirectory.nativePath + "/data1new.pkg";
			var dataPackFile:File = new File(path);
			var stream:FileStream = new FileStream();
			stream.open(dataPackFile, FileMode.WRITE);
			var saveData:ByteArray = new ByteArray();
			saveData.endian = Endian.LITTLE_ENDIAN;
			saveData.writeUnsignedInt(1060388615);
			saveData.writeInt(0);
			saveData.writeInt(_totalCount);
			var xlsData:ByteArray = new ByteArray();
			xlsData.endian = Endian.LITTLE_ENDIAN;
			for (var key:* in _xlsDataDict)
			{
				xlsData.writeBytes(_xlsDataDict[key]);
			}
			xlsData.compress();
			saveData.writeBytes(xlsData);
			stream.writeBytes(saveData);
			stream.close();
			trace("打包完毕");
		}
	}
}