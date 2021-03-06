/*
 * Scratch Project Editor and Player
 * Copyright (C) 2014 Massachusetts Institute of Technology
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

// ScriptsPart.as
// John Maloney, November 2011
//
// This part holds the palette and scripts pane for the current sprite (or stage).

package ui.parts {
	import flash.display.Bitmap;
	import flash.display.Graphics;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	
	import blocks.Block;
	
	import cc.makeblock.util.HexUtil;
	
	import extensions.ArduinoManager;
	import extensions.ConnectionManager;
	import extensions.SerialDevice;
	import extensions.SerialManager;
	
	import scratch.ScratchObj;
	import scratch.ScratchSprite;
	import scratch.ScratchStage;
	
	import translation.Translator;
	
	import ui.BlockPalette;
	import ui.PaletteSelector;
	
	import uiwidgets.Button;
	import uiwidgets.DialogBox;
	import uiwidgets.IndicatorLight;
	import uiwidgets.ScriptsPane;
	import uiwidgets.ScrollFrame;
	import uiwidgets.TextPane;
	import uiwidgets.ZoomWidget;
	
	import util.JSON;
	import util.JsUtil;

public class ScriptsPart extends UIPart {

	private var shape:Shape;
	public var selector:PaletteSelector;
	private var spriteWatermark:Bitmap;
	private var paletteFrame:ScrollFrame;
	private var scriptsFrame:ScrollFrame;
	private var arduinoFrame:ScrollFrame;
	private var arduinoTextPane:TextPane;
	private var messageTextPane:TextPane;
	private var lineNumText:TextField;
	private var zoomWidget:ZoomWidget;

	private var lineNumWidth:uint = 20;
	private const readoutLabelFormat:TextFormat = new TextFormat(CSS.font, 12, CSS.textColor, true);
	private const readoutFormat:TextFormat = new TextFormat(CSS.font, 12, CSS.textColor);

	private var xyDisplay:Sprite;
	private var xLabel:TextField;
	private var yLabel:TextField;
	private var xReadout:TextField;
	private var yReadout:TextField;
	private var lastX:int = -10000000; // impossible value to force initial update
	private var lastY:int = -10000000; // impossible value to force initial update
	private var backBt:Button = new Button(Translator.map("Back"));
	private var uploadBt:Button = new Button(Translator.map("Upload to Arduino"));
	private var openBt:Button = new Button(Translator.map("Open with Arduino IDE"));
	private var sendBt:Button = new Button(Translator.map("Send"));
	private var sendTextPane:TextPane;
	
	private var isByteDisplayMode:Boolean = true;
	private var displayModeBtn:Button = new Button(Translator.map("binary mode"));
	
	private var isByteInputMode:Boolean = false;
	private var inputModeBtn:Button = new Button(Translator.map("char mode"));
	
	public function ScriptsPart(app:MBlock) {
		this.app = app;

		addChild(shape = new Shape());
		addChild(spriteWatermark = new Bitmap());
		addXYDisplay();
		addChild(selector = new PaletteSelector(app));

		var palette:BlockPalette = new BlockPalette();
		palette.color = CSS.tabColor;
		paletteFrame = new ScrollFrame();
		paletteFrame.allowHorizontalScrollbar = false;
		paletteFrame.setContents(palette);
		addChild(paletteFrame);

		var scriptsPane:ScriptsPane = new ScriptsPane(app);
		scriptsFrame = new ScrollFrame(true);
		scriptsFrame.setContents(scriptsPane);
		addChild(scriptsFrame);
		
		app.palette = palette;
		app.scriptsPane = scriptsPane;

		addChild(zoomWidget = new ZoomWidget(scriptsPane));
		
		arduinoFrame = new ScrollFrame(false);
		arduinoFrame.visible = false;
		
		arduinoTextPane = new TextPane();
//		arduinoTextPane.type = TextFieldType.INPUT;
		var ft:TextFormat = new TextFormat("Arial",14,0x00325a);
		ft.blockIndent = 5;
		arduinoTextPane.textField.defaultTextFormat = ft;
		arduinoTextPane.textField.background = true;
		arduinoTextPane.textField.backgroundColor = 0xfcfcfc;
		arduinoTextPane.textField.type = TextFieldType.DYNAMIC;
		
		messageTextPane = new TextPane;
		messageTextPane.textField.defaultTextFormat = ft;
		messageTextPane.textField.background = true;
		messageTextPane.textField.backgroundColor = 0xc8c8c8;
		
		sendTextPane = new TextPane();
		sendTextPane.textField.defaultTextFormat = ft;
		sendTextPane.textField.background = true;
		sendTextPane.textField.backgroundColor = 0xf8f8f8;
		sendTextPane.textField.type = TextFieldType.INPUT;
		sendTextPane.textField.multiline = false;
		sendTextPane.scrollbar.visible = false;
		
		lineNumText = new TextField;
		lineNumText.defaultTextFormat = new TextFormat("Arial",14,0x8a8a8a);
		lineNumText.selectable = false;
		arduinoTextPane.textField.addEventListener(Event.SCROLL,onScroll);
		backBt.x = 10;
		backBt.y = 10;
		backBt.addEventListener(MouseEvent.CLICK,onHideArduino);
		arduinoFrame.addChild(backBt);
		uploadBt.x = 70;
		uploadBt.y = 10;
		uploadBt.addEventListener(MouseEvent.CLICK,onCompileArduino);
		arduinoFrame.addChild(uploadBt);
		
		openBt.y = 10;
		openBt.addEventListener(MouseEvent.CLICK,onOpenArduinoIDE);
		
		sendBt.addEventListener(MouseEvent.CLICK,onSendSerial);
		displayModeBtn.addEventListener(MouseEvent.CLICK,onDisplayModeChange);
		inputModeBtn.addEventListener(MouseEvent.CLICK,onInputModeChange);
		onInputModeChange(null);
		arduinoFrame.addChild(openBt);
		arduinoFrame.addChild(arduinoTextPane);
		arduinoFrame.addChild(messageTextPane);
		arduinoFrame.addChild(lineNumText);
		arduinoFrame.addChild(sendTextPane);
		arduinoFrame.addChild(sendBt);
		arduinoFrame.addChild(displayModeBtn);
		arduinoFrame.addChild(inputModeBtn);
		addChild(arduinoFrame);
		
		paletteFrame.addEventListener(MouseEvent.ROLL_OVER, __onMouseOver);
		paletteFrame.addEventListener(MouseEvent.ROLL_OUT, __onMouseOut);
		paletteIndex = getChildIndex(paletteFrame);
	}
	
	private var paletteIndex:int;
	private var maskWidth:int;
	//private var paletteShape:Sprite = new Sprite();
	private function __onMouseOver(event:MouseEvent):void
	{
		setChildIndex(paletteFrame, numChildren-1);
		paletteFrame.addEventListener(Event.ENTER_FRAME, __onEnterFrame);
		maskWidth = 0;
		if(app.palette.width>BlockPalette.WIDTH)
		{
			
			if(!paletteFrame.paletteShape)
			{
				paletteFrame.paletteShape = new Sprite();
			}
			paletteFrame.paletteShape.graphics.clear();
			paletteFrame.paletteShape.graphics.lineStyle(0.1,0xABABAB,0.5);
			paletteFrame.paletteShape.graphics.beginFill(0xE6E8E8,1);
			paletteFrame.paletteShape.graphics.drawRect(0,0,app.palette.width+10,h - paletteFrame.y - 2);
			paletteFrame.paletteShape.graphics.endFill();
			paletteFrame.addChildAt(paletteFrame.paletteShape,0);
			paletteFrame.fixLayout();
		}
		
	}

	private function __onEnterFrame(event:Event):void
	{
		if(maskWidth < app.palette.width){
			maskWidth += 30;
			paletteFrame.showRightPart(maskWidth);
		}
		if(paletteFrame.mouseX > BlockPalette.WIDTH){
			//__onMouseOut(null);
		}
	}
	
	private function __onMouseOut(event:MouseEvent):void
	{
		paletteFrame.removeEventListener(Event.ENTER_FRAME, __onEnterFrame);
		paletteFrame.hideRightPart();
		setChildIndex(paletteFrame, paletteIndex);
		if(paletteFrame.paletteShape && paletteFrame.paletteShape.parent)
		{
			paletteFrame.removeChild(paletteFrame.paletteShape);
			paletteFrame.paletteShape = null;
		}
		paletteFrame.fixLayout();
		trace("paletteFrame.width2="+paletteFrame.width)
	}
	
	private function onInputModeChange(evt:MouseEvent):void
	{
		var str:String = sendTextPane.textField.text;
		isByteInputMode = !isByteInputMode;
		if(isByteInputMode){
			sendTextPane.textField.restrict = "0-9 a-fA-F";
			inputModeBtn.setLabel(Translator.map("binary mode"));
		}else{
			sendTextPane.textField.restrict = null;
			inputModeBtn.setLabel(Translator.map("char mode"));
		}
		if(str.length <= 0){
			return;
		}
		var bytes:ByteArray;
		if(isByteInputMode){
			bytes = new ByteArray();
			bytes.writeUTFBytes(str);
			sendTextPane.textField.text = HexUtil.bytesToString(bytes);
		}else{
			bytes = HexUtil.stringToBytes(str);
			sendTextPane.textField.text = bytes.readUTFBytes(bytes.length);
		}
		bytes.clear();
	}
	
	private function onDisplayModeChange(evt:MouseEvent):void
	{
		isByteDisplayMode = !isByteDisplayMode;
		if(isByteDisplayMode){
			displayModeBtn.setLabel(Translator.map("binary mode"));
		}else{
			displayModeBtn.setLabel(Translator.map("char mode"));
		}
	}
	public function appendMessage(msg:String):void{
		appendRawMessage(msg+"\n");
	}
	public function appendRawMessage(msg:String):void{
		messageTextPane.textField.appendText(msg);
		if(messageTextPane.textField.length > 2000) {
			var text:String = messageTextPane.textField.text;
			messageTextPane.textField.text = text.substr(text.length-1000);
		}
		messageTextPane.textField.scrollV = messageTextPane.textField.maxScrollV-1;
	}
	
	public function onSerialSend(bytes:ByteArray):void
	{
		if(!MBlock.app.stageIsArduino){
			return;
		}
		if(isByteInputMode){
			appendMsgWithTimestamp(HexUtil.bytesToString(bytes), true);
		}else{
			bytes.position = 0;
			var str:String = bytes.readUTFBytes(bytes.length);
			appendMsgWithTimestamp(str, true);
		}
	}
	public function appendMsgFromJs(msg:String,isOut:Boolean):void
	{
		var arr:Array = msg.split(",");
		if(isByteDisplayMode)
		{
			for(var i:int=0;i<arr.length;i++)
			{
				arr[i] = Number(arr[i]).toString(16);
				if(arr[i].length<2)
				{
					arr[i] = "0"+arr[i];
				}
			}
			var tmpmsg:String = arr.join(" ");
		}
		else
		{
			var ba:ByteArray = new ByteArray();
			for(i=0;i<arr.length;i++)
			{
				ba[i] = arr[i];
			}
			tmpmsg = ba.readUTFBytes(ba.length);
		}
		
		appendMsgWithTimestamp(tmpmsg,isOut);
	}
	public function appendMsgWithTimestamp(msg:String, isOut:Boolean):void
	{
		var date:Date = new Date();
		var sendType:String = isOut ? " > " : " < ";
		
		msg = changeStamp(date.hours) + ":" + changeStamp(date.minutes) + ":" + changeStamp(date.seconds) + "." +changeStamp(date.milliseconds,3) + sendType + msg;
		appendMessage(msg);
	}
	private function changeStamp(value:Number,count:int=2):String
	{
		var result:String=value.toString();
		while(result.length<count)
		{
			result='0'+result;
		}
		return result;
	}
	public function onSerialDataReceived(bytes:ByteArray):void{
		appendMsgWithTimestamp(HexUtil.bytesToString(bytes), false);
		/*
		return;
		var date:Date = new Date;
		var s:String = SerialManager.sharedManager().asciiString;
		if(s.charCodeAt(0)==20){
			return;
		}
		appendMessage(""+(date.month+1)+"-"+date.date+" "+date.hours+":"+date.minutes+":"+(date.seconds+date.milliseconds/1000)+" < "+SerialManager.sharedManager().asciiString.split("\r\n").join("")+"\n");
		*/
	}
	private function onSendSerial(evt:MouseEvent):void{
		if(!SerialDevice.sharedDevice().connected){
			return;
		}
		var str:String = sendTextPane.textField.text;
		if(str.length <= 0){
			return;
		}
		var sendData:Array = [];
		var bytes:ByteArray;
		if(isByteInputMode){
			bytes = HexUtil.stringToBytes(str);
			for(var i:int=0;i<bytes.length;i++)
			{
				sendData[i] = bytes[i];
			}
			JsUtil.callApp("sendBytesToBoard",sendData);
		}else{
			bytes = new ByteArray();
			bytes.writeUTFBytes(str + "\n");
			JsUtil.callApp("sendBytesToBoard",str);
		}
		//onSerialSend(bytes);
		ConnectionManager.sharedManager().sendBytes(bytes);
//		var date:Date = new Date;
//		messageTextPane.append(""+(date.month+1)+"-"+date.date+" "+date.hours+":"+date.minutes+":"+(date.seconds+date.milliseconds/1000)+" > "+sendTextPane.textField.text+"\n");
		
//		messageTextPane.textField.scrollV = messageTextPane.textField.maxScrollV-1;
	}
	public function get isArduinoMode():Boolean{
		return arduinoFrame.visible;
	}
	private function onCompileArduino(evt:MouseEvent):void{
		JsUtil.callApp("uploadToArduino", arduinoTextPane.textField.text);
		return;
		
		if(SerialManager.sharedManager().isConnected){
			if(ArduinoManager.sharedManager().isUploading==false){
				messageTextPane.clear();
				if(showArduinoCode()){
					messageTextPane.append(ArduinoManager.sharedManager().buildAll(arduinoTextPane.textField.text));
				}
			}
		}else{
			var dialog:DialogBox = new DialogBox();
			dialog.addTitle("Message");
			dialog.addText("Please connect the serial port.");
			function onCancel():void{
				dialog.cancel();
			}
			dialog.addButton("OK",onCancel);
			dialog.showOnStage(app.stage);
		}
	}
	private function onHideArduino(evt:MouseEvent):void{
		app.toggleArduinoMode();
	}
	private function onOpenArduinoIDE(evt:MouseEvent):void{
		if(showArduinoCode()){
			JsUtil.callApp("openArduinoIDE", arduinoTextPane.textField.text);
		}
	}
	private function onScroll(evt:Event):void{
		lineNumText.scrollV = arduinoTextPane.textField.scrollV;
	}
	
	static private const classNameList:Array = [
		"SoftwareSerial",
		"MeBoard",
		"MeDCMotor",
		"MeServo",
		"MeIR",
		"Me7SegmentDisplay",
		"MeRGBLed",
		"MePort",
		"MeGyro",
		"MeJoystick",
		"MeLight",
		"MeSound",
		"MeStepper",
		"MeEncoderMotor",
		"MeInfraredReceiver",
		"MeTemperature",
		"MeUltrasonicSensor",
		"MeSerial",
		"Servo",
		"mBot",
		"Arduino",
	];
	
	public function showArduinoCode(arg:String=""):Boolean{
		var retcode:String = util.JSON.stringify(app.stagePane);
		var formatCode:String = ArduinoManager.sharedManager().jsonToCpp(retcode);
		uploadBt.visible = !ArduinoManager.sharedManager().hasUnknownCode;
		if(formatCode==null){
			return false;
		}
		if(!app.stageIsArduino){
			app.toggleArduinoMode();
		}
		for(var i:uint=0;i<5;i++){
			formatCode = formatCode.split("\r\n\r\n").join("\r\n").split("\r\n\t\r\n").join("\r\n");
		}
		var codes:Array = formatCode.split("\n");
		arduinoTextPane.setText(formatCode);
		var fontGreen:TextFormat = new TextFormat("Arial",14,0x006633);
		var fontYellow:TextFormat = new TextFormat("Arial",14,0x999900);
		var fontOrange:TextFormat = new TextFormat("Arial",14,0x996600);
		var fontRed:TextFormat = new TextFormat("Arial",14,0x990000);
		var fontBlue:TextFormat = new TextFormat("Arial",14,0x000099);
		formatKeyword(arduinoTextPane.textField,"String ",fontRed,0,1);
		formatKeyword(arduinoTextPane.textField,"int ",fontRed,0,1);
		formatKeyword(arduinoTextPane.textField,"char ",fontRed,0,1);
		formatKeyword(arduinoTextPane.textField,"double ",fontRed,0,1); 
		formatKeyword(arduinoTextPane.textField,"boolean ",fontRed,0,1);
		formatKeyword(arduinoTextPane.textField,"false",fontRed,0,0);
		formatKeyword(arduinoTextPane.textField,"true",fontRed,0,0);
		formatKeyword(arduinoTextPane.textField,"void ",fontOrange,0,1);
		formatKeyword(arduinoTextPane.textField,"for(",fontOrange,0,1);
		formatKeyword(arduinoTextPane.textField,"if(",fontOrange,0,1);
		formatKeyword(arduinoTextPane.textField,"else{",fontOrange,0,1);
		formatKeyword(arduinoTextPane.textField,"while(",fontOrange,0,1);
		formatKeyword(arduinoTextPane.textField,"#include ",fontRed,0,1);
		
		formatKeyword(arduinoTextPane.textField," setup()",fontRed,1,2);
		formatKeyword(arduinoTextPane.textField," loop()",fontRed,1,2);
		formatKeyword(arduinoTextPane.textField,"Serial.",fontRed,0,1);
		formatKeyword(arduinoTextPane.textField,".begin(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".available(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".println(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".print(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".read(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".length(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,"return ",fontOrange,0,1);
		formatKeyword(arduinoTextPane.textField,".run(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".runSpeed(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".setMaxSpeed(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".move(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".moveTo(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".attach(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".charAt(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,"memset",fontOrange,0,0);
		formatKeyword(arduinoTextPane.textField,".write(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".display(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".setColorAt(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".show(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".dWrite1(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".dWrite2(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".dRead1(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,".dRead2(",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,"(M1)",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,"(M2)",fontOrange,1,1);
		formatKeyword(arduinoTextPane.textField,"SLOT_1",fontOrange,0,0);
		formatKeyword(arduinoTextPane.textField,"SLOT_2",fontOrange,0,0);
		formatKeyword(arduinoTextPane.textField,"PORT_1",fontOrange,0,0);
		formatKeyword(arduinoTextPane.textField,"PORT_2",fontOrange,0,0);
		formatKeyword(arduinoTextPane.textField,"PORT_3",fontOrange,0,0);
		formatKeyword(arduinoTextPane.textField,"PORT_4",fontOrange,0,0);
		formatKeyword(arduinoTextPane.textField,"PORT_5",fontOrange,0,0);
		formatKeyword(arduinoTextPane.textField,"PORT_6",fontOrange,0,0);
		formatKeyword(arduinoTextPane.textField,"PORT_7",fontOrange,0,0);
		formatKeyword(arduinoTextPane.textField,"PORT_8",fontOrange,0,0);
		formatKeyword(arduinoTextPane.textField,"delay(",fontRed,0,1);
		formatKeyword(arduinoTextPane.textField,"OUTPUT)",fontOrange,0,1);
		formatKeyword(arduinoTextPane.textField,"INPUT)",fontOrange,0,1);
		formatKeyword(arduinoTextPane.textField,"pinMode(",fontRed,0,1);
		formatKeyword(arduinoTextPane.textField,"digitalWrite(",fontRed,0,1);
		formatKeyword(arduinoTextPane.textField,"digitalRead(",fontRed,0,1);
		formatKeyword(arduinoTextPane.textField,"analogWrite(",fontRed,0,1);
		formatKeyword(arduinoTextPane.textField,"analogRead(",fontRed,0,1);
		formatKeyword(arduinoTextPane.textField,"getAngle(",fontRed,0,1);
		formatKeyword(arduinoTextPane.textField,"refresh(",fontRed,0,1);
		formatKeyword(arduinoTextPane.textField,"update(",fontRed,0,1);
		
		formatKeyword(arduinoTextPane.textField,"tone(",fontRed,0,1);
		formatKeyword(arduinoTextPane.textField,"noTone(",fontRed,0,1);
		formatKeyword(arduinoTextPane.textField,"Wire.",fontGreen,0,1);
		
		for each(var clsName:String in classNameList){
			formatKeyword(arduinoTextPane.textField, clsName, fontGreen, 0, 0);
		}
		
		
		lineNumText.text = "";
		var preS:String = "";
		var t:Number = arduinoTextPane.textField.numLines;
		var tt:uint = 0;
		while(t>1){
			t/=10;
			preS+="0";
			tt++;
		}
		lineNumWidth = tt*10;
		fixlayout();
		for(i = 0;i<arduinoTextPane.textField.numLines;i++){
			lineNumText.appendText((preS+(i+1)).substr(-tt,tt)+".\n");
		}
		if(ArduinoManager.sharedManager().hasUnknownCode){
			if(!isDialogBoxShowing){
				isDialogBoxShowing = true;
				var dBox:DialogBox = new DialogBox();
				dBox.addTitle(Translator.map("unsupported block found, remove them to continue."));
				for each(var b:Block in ArduinoManager.sharedManager().unknownBlocks){
					b.mouseEnabled = false;
					b.mouseChildren = false;
					dBox.addBlock(b);
				}
				function cancelHandle():void{
					isDialogBoxShowing = false;
					dBox.cancel();
				}
				dBox.addButton("OK",cancelHandle);
				dBox.showOnStage(app.stage);
				dBox.fixLayout();
			}
			arduinoFrame.visible = false;
			if(app.stageIsArduino){
				app.toggleArduinoMode();
			}
		}else{
			arduinoFrame.visible = true;
		}
		return true;
	}
	static private var isDialogBoxShowing:Boolean;
	private function formatKeyword(txt:TextField,word:String,format:TextFormat,subStart:uint=0,subEnd:uint=0):void
	{
		var index:int = 0;
		var msg:String = txt.text;
		for(;;){
			index = msg.indexOf(word, index);
			if(index < 0){
				break;
			}
			txt.setTextFormat(format, index + subStart, index + word.length - subEnd);
			index += word.length;
		}
	}
	public function resetCategory():void { selector.select(Specs.motionCategory) }

	public function updatePalette():void {
		selector.updateTranslation();
		if(!MBlock.app.stageIsArduino && MBlock.app.viewedObj() is ScratchStage){
			if(selector.selectedCategory == Specs.motionCategory){
				selector.selectedCategory = Specs.looksCategory;
			}
		}
		selector.select(selector.selectedCategory);
	}
	public function updateTranslation():void{
		backBt.setLabel(Translator.map("Back"));
		uploadBt.setLabel(Translator.map("Upload to Arduino"));
		openBt.setLabel(Translator.map("Edit with Arduino IDE"));
		sendBt.setLabel(Translator.map("Send"));
		displayModeBtn.setLabel(Translator.map(isByteDisplayMode ? "binary mode" :  "char mode"));
		inputModeBtn.setLabel(Translator.map(isByteInputMode ? "binary mode" :  "char mode"));
	}
	public function updateSpriteWatermark():void {
		var target:ScratchObj = app.viewedObj();
		if (target && !target.isStage) {
			spriteWatermark.bitmapData = target.currentCostume().thumbnail(40, 40, false);
		} else {
			spriteWatermark.bitmapData = null;
		}
	}

	public function step():void {
		// Update the mouse reaadouts. Do nothing if they are up-to-date (to minimize CPU load).
		var target:ScratchObj = app.viewedObj();
		if(target == null){
			return;
		}
		if (target.isStage) {
			if (xyDisplay.visible) xyDisplay.visible = false;
		} else {
			if (!xyDisplay.visible) xyDisplay.visible = true;

			var spr:ScratchSprite = target as ScratchSprite;
			if (!spr) return;
			if (spr.scratchX != lastX) {
				lastX = spr.scratchX;
				xReadout.text = String(lastX);
			}
			if (spr.scratchY != lastY) {
				lastY = spr.scratchY;
				yReadout.text = String(lastY);
			}
		}
		updateExtensionIndicators();
	}

	private var lastUpdateTime:uint;

	private function updateExtensionIndicators():void {
		if ((getTimer() - lastUpdateTime) < 500) return;
		for (var i:int = 0; i < app.palette.numChildren; i++) {
			var indicator:IndicatorLight = app.palette.getChildAt(i) as IndicatorLight;
			if (indicator) app.extensionManager.updateIndicator(indicator, indicator.target);
		}		
		lastUpdateTime = getTimer();
	}

	public function setWidthHeight(w:int, h:int):void {
		this.w = w;
		this.h = h;
		fixlayout();
		redraw();
	}

	private function fixlayout():void {
		selector.x = 1;
		selector.y = 5;
		paletteFrame.x = selector.x;
		paletteFrame.y = selector.y + selector.height + 2;
		paletteFrame.setWidthHeight(selector.width + 1, h - paletteFrame.y - 2); // ????????????????????????
		scriptsFrame.x = selector.x + selector.width + 2;
		scriptsFrame.y = selector.y + 1;
		var arduinoWidth:uint = app.stageIsArduino?(w/2-150):0;
		var arduinoHeight:uint = h - 10;
		arduinoFrame.visible = app.stageIsArduino;
		scriptsFrame.setWidthHeight(w - scriptsFrame.x - 15-arduinoWidth, h - scriptsFrame.y - 5);//?????????
		arduinoFrame.x = scriptsFrame.x+ (w - scriptsFrame.x - 15-arduinoWidth)+10;
		arduinoFrame.y = scriptsFrame.y;
		arduinoFrame.setWidthHeight(arduinoWidth, arduinoHeight);
		lineNumText.x = 4;
		lineNumText.y = 45;
		lineNumText.width = lineNumWidth;
		lineNumText.height = arduinoHeight-255;
		arduinoTextPane.setWidthHeight(arduinoWidth-lineNumWidth-lineNumText.x-5,arduinoHeight-255);
		arduinoTextPane.x = lineNumText.x+lineNumText.width+5;
		arduinoTextPane.y = 45;
		messageTextPane.x = lineNumText.x;
		messageTextPane.y = arduinoHeight-200;
		messageTextPane.setWidthHeight(arduinoWidth-messageTextPane.x,155);
		openBt.x = arduinoWidth - openBt.width - 10;
		sendTextPane.x = 8 + displayModeBtn.width;
		sendTextPane.y = arduinoHeight - 33;
		sendTextPane.setWidthHeight(arduinoWidth-sendBt.width-sendTextPane.x-10,20);
		sendBt.x = arduinoWidth - sendBt.width - 10;
		sendBt.y = arduinoHeight - 35;
		displayModeBtn.x = messageTextPane.x + messageTextPane.width - displayModeBtn.width;
		displayModeBtn.y = messageTextPane.y;
		inputModeBtn.x = lineNumText.x;
		inputModeBtn.y = sendBt.y;
		arduinoTextPane.updateScrollbar(null);
		messageTextPane.updateScrollbar(null);
		spriteWatermark.x = w - arduinoWidth - 60;
		spriteWatermark.y = scriptsFrame.y + 10;
		xyDisplay.x = spriteWatermark.x + 1;
		xyDisplay.y = spriteWatermark.y + 43;
		zoomWidget.x = w - arduinoWidth - zoomWidget.width - 30;
		zoomWidget.y = h - zoomWidget.height - 15;
	}

	private function redraw():void {
		var paletteW:int = paletteFrame.visibleW();
		var paletteH:int = paletteFrame.visibleH();
		var scriptsW:int = scriptsFrame.visibleW();
		var scriptsH:int = scriptsFrame.visibleH();

		var g:Graphics = shape.graphics;
		g.clear();
		g.lineStyle(1, CSS.borderColor, 1, true);
		g.beginFill(CSS.tabColor);
		g.drawRect(0, 0, w, h);
		g.endFill();

		var lineY:int = selector.y + selector.height;
		var darkerBorder:int = CSS.borderColor - 0x141414;
		var lighterBorder:int = 0xF2F2F2;
		g.lineStyle(1, darkerBorder, 1, true);
		hLine(g, paletteFrame.x + 8, lineY, paletteW - 20);
		g.lineStyle(1, lighterBorder, 1, true);
		hLine(g, paletteFrame.x + 8, lineY + 1, paletteW - 20);

		g.lineStyle(1, darkerBorder, 1, true);
		g.drawRect(scriptsFrame.x - 1, scriptsFrame.y - 1, scriptsW + 1, scriptsH + 1);
	}

	private function hLine(g:Graphics, x:int, y:int, w:int):void {
		g.moveTo(x, y);
		g.lineTo(x + w, y);
	}

	private function addXYDisplay():void {
		xyDisplay = new Sprite();
		xyDisplay.addChild(xLabel = makeLabel('x:', readoutLabelFormat, 0, 0));
		xyDisplay.addChild(xReadout = makeLabel('-888', readoutFormat, 15, 0));
		xyDisplay.addChild(yLabel = makeLabel('y:', readoutLabelFormat, 0, 13));
		xyDisplay.addChild(yReadout = makeLabel('-888', readoutFormat, 15, 13));
		addChild(xyDisplay);
	}

}}
