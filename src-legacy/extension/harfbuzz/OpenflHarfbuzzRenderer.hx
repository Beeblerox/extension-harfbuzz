package extension.harfbuzz;

import extension.harfbuzz.OpenflHarbuzzCFFI;
import extension.harfbuzz.TextScript;
import extension.harfbuzz.TilesRenderer.RenderItem;
import extension.icu.Icu;
import haxe.Utf8;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.Lib;
import openfl.utils.ByteArray;


@:publicFields
class RenderData
{
	var renderList:Array<RenderItem> = [];
	var linesLength:Array<Int> = [];
	var linesWidth:Array<Float> = [];
	var linesNumber:Int = 0;
	
	var colors:Array<Int>;
	var colored:Bool = false;
	
	function new()
	{
		
	}
}

@:publicFields
class ChunkGroup
{
	var direction:TextDirection;
	var chunks:Array<TextChunk> = [];
	
	function new()
	{
		
	}
}

@:publicFields
class TextChunk
{
	var start:Int;
	var length:Int = 0;
	var script:TextScript;
	
	var width:Float = 0.0;
	
	function new()
	{
		
	}
}

class OpenflHarfbuzzRenderer 
{
	static dynamic public function getBytes(src:String) 
	{
        return openfl.Assets.getBytes(src);
    }
	
	static var harfbuzzIsInited = false;
	
	var face:FTFace;

	public var direction(default, null):TextDirection;
	public var script(default, null):TextScript;
	public var language(default, null):String;
	public var fontName(default, null):String;
	
	public var lineHeight(default, null):Float;
	
	public var renderer(default, null):TilesRenderer;
	
	var chunkGroups:Array<ChunkGroup> = [];
	
	public function new(
			fontName:String,	// Font path or Openfl Asset ID
			textSize:Int,
			color:Int,
			text:String,
			language:String = "",
			script:TextScript = null,
			direction:TextDirection = null) 
	{

		if (script == null) 
		{
			script = ScriptIdentificator.identify(text);
		}
		this.script = script;

		if (direction == null) 
		{
			direction = TextScriptTools.isRightToLeft(script) ? RightToLeft : LeftToRight;
		}
		this.direction = direction;

		this.language = language;
		this.lineHeight = textSize;

		if (!harfbuzzIsInited) 
		{
			OpenflHarbuzzCFFI.init();
			harfbuzzIsInited = true;
		}

		this.fontName = fontName;

		if (sys.FileSystem.exists(fontName)) 
		{
			face = OpenflHarbuzzCFFI.loadFontFaceFromFile(fontName);
		} 
		else
		{
		//	#if (!openfl_next)
			face = OpenflHarbuzzCFFI.loadFontFaceFromMemory(getBytes(fontName).getData());
		//	#else
		//	face = OpenflHarbuzzCFFI.loadFontFaceFromMemory(getBytes(fontName));
		//	#end
		}

		OpenflHarbuzzCFFI.setFontSize(face, textSize);

		var glyphData = OpenflHarbuzzCFFI.createGlyphData(face, createBuffer(text));
		renderer = new TilesRenderer(glyphData, 1024, color);
	}
	
	public function cleanup():Void
	{
		if (renderer != null)
		{
			renderer.cleanup();
		}

		renderer = null;
		face = null;
	}

	function createBuffer(text:String):HBBuffer 
	{
		return OpenflHarbuzzCFFI.createBuffer(direction, script, language, text);
	}

	function isPunctuationCode(charCode:Int) 
	{
		return
			charCode == 46 		||	// dot
			charCode == 44 		|| 	// comma
			charCode == 58 		||	// colon
			charCode == 59 		||	// semi-colon
			charCode == 45 		||	// minus or dash
			charCode == 95 		||	// underscore
			charCode == 91 		||	// left/opening bracket
			charCode == 93 		||	// right/closing bracket
			charCode == 40 		||	// left/opening parenthesis
			charCode == 41;			// right/closing parenthesis	
	}

	private function isSpaceCode(i:Int)
	{
		return (i > 8 && i < 14) || i == 32;
	}
	
	function splitText(textCodes:Array<Int>, start:Int, length:Int):Array<String>
	{
		var ret = [];
		var currentWord:Utf8 = null;
		
		for (i in 0...length)
		{
			var index:Int = start + i;
			var cCode:Int = textCodes[index];
			
			if (cCode == 13) continue;
			if (isSpaceCode(cCode)) 
			{
				if (currentWord != null) 
				{
					ret.push(currentWord.toString());
				}
				
				currentWord = new Utf8();
				currentWord.addChar(cCode);
				ret.push(currentWord.toString());
				currentWord = null;
				
				continue;
			}
			
			if (currentWord == null) 
			{
				currentWord = new Utf8();
			}
			
			currentWord.addChar(cCode);
			
			if (isPunctuationCode(cCode))
			{
				ret.push(currentWord.toString());
				currentWord = null;
			}
		}
		
		if (currentWord != null) 
		{
			ret.push(currentWord.toString());
		}
		
		return ret;
	}

	function layoutWidth(layout:Array<PosInfo>, fontScale:Float = 1.0, letterSpacing:Float = 0.0):Float 
	{
		var xPos = 0.0;
		for (posInfo in layout) 
		{
			xPos += posInfo.advance.x / (100 / 64) * fontScale + letterSpacing;	// 100/64 = 1.5625 = Magic!
		}
		return xPos;
	}

	function isEndOfLine(xPos:Float, wordWidth:Float, lineWidth:Float) 
	{
		if (lineWidth <= 0) return false;
		
		if (direction == LeftToRight) 
		{
			return (xPos > 0.0 && xPos + wordWidth > lineWidth);
		} 
		else 
		{	// RightToLeft
			return (xPos < lineWidth && xPos - wordWidth < 0.0);
		}
	}
	
	function getCharCodes(text:String):Array<Int>
	{
		var result:Array<Int> = [];
		Utf8.iter(text, function(cCode:Int)
		{
			result.push(cCode);
		});
		
		return result;
	}
	
	function popSpaces(line:Array<String>):Int
	{
		var delta:Int = 0;
		while (line.length > 0) // pop spaces
		{
			if (StringTools.isSpace(line[line.length - 1], 0))
			{
				var word = line.pop();
				delta += Utf8.length(word);
			}
			else
			{
				break;
			}
		}
		
		return delta;
	}
	
	// TODO: restore text coloring...
	// added support for autosized fields (if fieldWidth <= 0)
	public function layoutText(text:String, renderData:RenderData, fieldWidth:Float = 0.0, fontScale:Float = 1.0, letterSpacing:Float = 0.0, ?letterColors:Array<Int>):RenderData
	{
		if (text == null || text.length == 0)
		{
			return renderData;
		}

		var renderList = renderData.renderList;
		var linesLength:Array<Int> = renderData.linesLength;
		var linesWidth:Array<Float> = renderData.linesWidth;
		var linesNumber:Int = 1;
		
		/*if (letterColors != null)
		{
			renderData.colors = [];
			renderData.colored = true;
		}*/

		fieldWidth = (fieldWidth < 0.0) ? 0.0 : fieldWidth;

		var lineXStart:Float = (direction == LeftToRight) ? 0.0 : fieldWidth;
		var xPosBase:Float = lineXStart;
		var yPosBase:Float = linesNumber * lineHeight * fontScale;
		var lineWidth:Float = 0.0;
		var lineLength:Int = 0;

		var colorIndex = 0;
		
		function pushToRenderList(string:String, renderedString:Array<PosInfo>, stringWidth:Float)
		{
			var xPos = xPosBase;
			if (direction == RightToLeft) xPos -= stringWidth;
			var yPos = yPosBase;

			for (posInfo in renderedString) 
			{
				var g = renderer.glyphs[posInfo.codepoint];
				if (g == null)
				{
					renderer.addGlyphs(OpenflHarbuzzCFFI.createGlyphData(face, createBuffer(string)));
				}
				
				g = renderer.glyphs[posInfo.codepoint];
				if (g == null) 
				{
	#if debug
					trace("WOW! I'm missing a glyph for the following word: " + string);
					trace("This should not be happening! Your text will be renderer badly :(");
					trace("CODEPINT " + posInfo.codepoint);
					trace(posInfo);
	#end
					colorIndex++;
					
					continue;
				}

				var dstX = (xPos + (posInfo.offset.x + g.bitmapLeft) * fontScale);
				var dstY = (yPos + (posInfo.offset.y - g.bitmapTop) * fontScale);

				var avanceX = posInfo.advance.x / (100 / 64) * fontScale; // 100/64 = 1.5625 = Magic!
				var avanceY = posInfo.advance.y / (100 / 64) * fontScale;

				if (fieldWidth > 0 && xPos + avanceX >= fieldWidth && direction == LeftToRight) 
				{
					linesWidth[linesNumber - 1] = lineWidth;
					linesLength[linesNumber - 1] = lineLength;

					// Newline
					linesNumber++;
					xPos = 0;
					yPos = linesNumber * lineHeight * fontScale;
					dstX = (xPos + (posInfo.offset.x + g.bitmapLeft) * fontScale);
					dstY = (yPos + (posInfo.offset.y - g.bitmapTop) * fontScale);

					lineWidth = 0;
					lineLength = 0;
				}

				renderList.push(new RenderItem(g.codepoint, dstX, dstY));
				lineLength++;

				if (renderData.colored)
				{
					renderData.colors.push(letterColors[colorIndex]);
				}
				
				colorIndex++;

				xPos += avanceX + letterSpacing;
				yPos += avanceY;
			}

			if (direction == LeftToRight) 
			{
				xPosBase += stringWidth;
			} 
			else 
			{
				xPosBase -= stringWidth;
			}
			
			lineWidth += stringWidth;
		}
		
		var textLines:Array<String> = text.split("\n");
		var numTextLines:Int = textLines.length;
		var counter:Int = 0;
		
		for (textLineIndex in 0...numTextLines)
		{
			var textLine:String = textLines[textLineIndex];
			var visualRuns = Icu.getVisualRuns(textLine, (direction == TextDirection.LeftToRight));
			var numVisualRuns = visualRuns.length;
			
			var charCodes:Array<Int> = getCharCodes(textLine);
			
			// reverse visual runs
			if (direction == TextDirection.RightToLeft) 
			{
				var numSwaps = Std.int(numVisualRuns / 2);
				for (i in 0...numSwaps)
				{
					var fromStartIndex = i;
					var fromEndIndex = numVisualRuns - i - 1;
					
					var runFromStart = visualRuns[fromStartIndex];
					var runFromEnd = visualRuns[fromEndIndex];
					
					visualRuns[fromStartIndex] = runFromEnd;
					visualRuns[fromEndIndex] = runFromStart;
				}
			}
			
			/*for (run in visualRuns)
			{
				trace("[start: " + run.start + ", length: " + run.length + ", direction: " + run.direction + "]");
				trace("[" + Utf8.sub(textLine, run.start, run.length) + "]");
			}*/
			
			for (run in visualRuns)
			{
				var runDirection:TextDirection = (run.direction == 0) ? TextDirection.LeftToRight : TextDirection.RightToLeft;
				var runWords = splitText(charCodes, run.start + counter, run.length);
				
				// TODO (Zaphod): continue from here...
				
				if (runDirection == TextDirection.LeftToRight && direction == TextDirection.RightToLeft)
				{
					var line:Array<String> = [];
					var lines = [];
					lines.push(line);
					
					var tempXpos:Float = xPosBase;
					
					for (word in runWords)
					{
						var renderedWord = OpenflHarbuzzCFFI.layoutText(face, OpenflHarbuzzCFFI.createBuffer(runDirection, script, language, word));
						var wordWidth = layoutWidth(renderedWord, fontScale, letterSpacing);
						
						if (isEndOfLine(tempXpos, wordWidth, fieldWidth))
						{
						//	var delta = popSpaces(line);
							
							line = [];
							lines.push(line);
							tempXpos = xPosBase;
							
							if (StringTools.isSpace(word, 0)) 
							{
						//		deltaLength[deltaLength.length - 1] += 1;
								continue;
							}
						}
						
						line.push(word);
						
						tempXpos -= wordWidth;
						
						if (isEndOfLine(tempXpos, wordWidth, fieldWidth))
						{	
						//	popSpaces(line);
							
							line = [];
							lines.push(line);
							
							tempXpos = xPosBase;
						}
					}
					
					for (i in 0...lines.length)
					{
						var lineText = lines[i].join("");
					//	var delta = deltaLength[i];
						
						var renderedLine = OpenflHarbuzzCFFI.layoutText(face, OpenflHarbuzzCFFI.createBuffer(runDirection, script, language, lineText));
						var renderedWidth = layoutWidth(renderedLine, fontScale, letterSpacing);
					
						if (i > 0 || isEndOfLine(xPosBase, renderedWidth, fieldWidth))
						{
							linesWidth[linesNumber - 1] = lineWidth;
							linesLength[linesNumber - 1] = lineLength;
							
							linesNumber++;
							yPosBase = linesNumber * lineHeight * fontScale;
							xPosBase = lineXStart;
							
							lineWidth = 0;
							lineLength = 0;
						}
						
						pushToRenderList(lineText, renderedLine, renderedWidth);
						
					//	colorIndex += delta;
					}
				}
				else
				{
					for (word in runWords)
					{
						var renderedWord = OpenflHarbuzzCFFI.layoutText(face, OpenflHarbuzzCFFI.createBuffer(runDirection, script, language, word));
						var wordWidth = layoutWidth(renderedWord, fontScale, letterSpacing);
						
						if (isEndOfLine(xPosBase, wordWidth, fieldWidth)) 
						{
							linesWidth[linesNumber - 1] = lineWidth;
							linesLength[linesNumber - 1] = lineLength;

							// Newline
							linesNumber++;
							xPosBase = lineXStart;
							yPosBase = linesNumber * lineHeight * fontScale;

							lineWidth = 0;
							lineLength = 0;

							if (StringTools.isSpace(word, 0)) 
							{
								colorIndex++;
								continue;
							}
						}
						
						pushToRenderList(word, renderedWord, wordWidth);
					}
				}
			}
			
			if (textLineIndex < numTextLines - 1)
			{
				linesNumber++;
			}
			
			counter++;
		}
		
		// flush everything that left
		linesWidth[linesNumber - 1] = lineWidth;
		linesLength[linesNumber - 1] = lineLength;	
		renderData.linesNumber = linesNumber;

		if (direction != LeftToRight && fieldWidth <= 0)
		{
			var maxLineWidth = linesWidth[0];
			for (i in 1...linesWidth.length)
			{
				maxLineWidth = Math.max(maxLineWidth, linesWidth[i]);
			}
			
			for (renderItem in renderData.renderList)
			{
				renderItem.x += maxLineWidth;
			}
		}
		
		return renderData;
	}

	public function renderText(text:String, lineWidth:Float = 400):HarfbuzzSprite 
	{
		var renderData = new RenderData();
		layoutText(text, renderData, lineWidth, 1.0, 0.0);
		return renderer.render(lineWidth, renderData.linesNumber * lineHeight, renderData.renderList);
	}
}
