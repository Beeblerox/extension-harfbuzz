package extension.harfbuzz;

import extension.harfbuzz.OpenflHarbuzzCFFI;
import extension.harfbuzz.TextScript;
import extension.harfbuzz.TilesRenderer.RenderItem;
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

	function isPunctuation(char:String) 
	{
		return
			char == '.' ||
			char == ',' ||
			char == ':' ||
			char == ';' ||
			char == '-' ||
			char == '_' ||
			char == '[' ||
			char == ']' ||
			char == '(' ||
			char == ')';
	}
	
	function isPunctuationCode(charCode:Int) 
	{
		return
			charCode == 46 ||	// dot
			charCode == 44 || 	// comma
			charCode == 58 ||	// colon
			charCode == 59 ||	// semi-colon
			charCode == 45 ||	// minus or dash
			charCode == 95 ||	// underscore
			charCode == 91 ||	// left/opening bracket
			charCode == 93 ||	// right/closing bracket
			charCode == 40 ||	// left/opening parenthesis
			charCode == 41;		// right/closing parenthesis
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
	
	function isEndOfLine2(xPos:Float, wordWidth:Float, lineWidth:Float) 
	{
		if (lineWidth <= 0) return false;
		return (xPos + wordWidth > lineWidth);
	}
	
	function popSpaces(line:Array<String>):Void
	{
		while (line.length > 0) // pop spaces
		{
			if (StringTools.isSpace(line[line.length - 1], 0))
			{
				line.pop();
			}
			else
			{
				break;
			}
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
	
	// break text into groups of chunks
	function preProcessText(textCodes:Array<Int>):Array<ChunkGroup>
	{
		var length:Int = textCodes.length;
		
		var chunkStart:Int = 0;
		var charCode:Int = textCodes[chunkStart];
		var currentScript:TextScript = ScriptIdentificator.getCharCodeScript(charCode);
		var currentDirection:TextDirection = TextScriptTools.isRightToLeft(currentScript) ? TextDirection.RightToLeft : TextDirection.LeftToRight;
		var prevDirection:TextDirection = currentDirection;
	
		var spacesChunk:TextChunk = null;
		var chunk:TextChunk = null;
		
		var chunks:Array<TextChunk> = [];
		
		if (isSpaceCode(charCode))
		{
			spacesChunk = new TextChunk();
			spacesChunk.start = chunkStart;
			spacesChunk.length = 1;
			spacesChunk.script = currentScript;
		}
		else
		{
			chunk = new TextChunk();
			chunk.start = chunkStart;
			chunk.length = 1;
			chunk.script = currentScript;
			
			chunks.push(chunk);
		}
		
		var currentGroup:ChunkGroup = new ChunkGroup();
		currentGroup.direction = currentDirection;
		currentGroup.chunks = chunks;
		
		chunkGroups = [];
		chunkGroups.push(currentGroup);
	
		// если справа или слева от последовательности пробелов имеем RTL текст, то выделяем последовательность пробелов в отдельную группу и добавляем ее в RTL группу...
		
		var prevDirection:TextDirection = currentDirection;
		
		var numSpaces:Int = isSpaceCode(charCode) ? 1 : 0;
		var counter:Int = 1;
		while (counter < length)
		{
			charCode = textCodes[counter];
			var charScript = ScriptIdentificator.getCharCodeScript(charCode);
			var charDirection:TextDirection = TextScriptTools.isRightToLeft(charScript) ? TextDirection.RightToLeft : TextDirection.LeftToRight;
			
			var isPunct = isPunctuationCode(charCode);
			
			if (isSpaceCode(charCode))
			{
				if (spacesChunk != null) // previous char is also a space char
				{
					spacesChunk.length++;
				}
				else
				{
					chunk = null;
					
					spacesChunk = new TextChunk();
					spacesChunk.start = counter;
					spacesChunk.length = 1;
					spacesChunk.script = charScript;
				}
			}
			else //if (!isSpace(charCode))
			{
				if (spacesChunk != null) // previous char is a space char
				{
					// decide where to put space chunk...
					if (prevDirection != charDirection) // need to start new chunk group
					{
						if (prevDirection == TextDirection.RightToLeft)
						{
							chunks.push(spacesChunk);
							
							chunks = [];
							currentGroup = new ChunkGroup();
							currentGroup.direction = charDirection;
							currentGroup.chunks = chunks;
							chunkGroups.push(currentGroup);
						}
						else // if (charDirection == TextDirection.RightToLeft)
						{
							chunks = [];
							currentGroup = new ChunkGroup();
							currentGroup.direction = charDirection;
							currentGroup.chunks = chunks;
							chunkGroups.push(currentGroup);
							
							chunks.push(spacesChunk);
						}
					}
					else
					{
						chunks.push(spacesChunk);
					}
					
					chunk = new TextChunk();
					chunk.start = counter;
					chunk.length = 1;
					chunk.script = charScript;
					
					chunks.push(chunk);
					
					spacesChunk = null;
				}
				else 
				{
					if (prevDirection != charDirection && !isPunct)
					{
						chunks = [];
						currentGroup = new ChunkGroup();
						currentGroup.direction = charDirection;
						currentGroup.chunks = chunks;
						chunkGroups.push(currentGroup);
						
						chunk = new TextChunk();
						chunk.start = counter;
						chunk.length = 1;
						chunk.script = charScript;
						
						chunks.push(chunk);
					}
					else
					{
						chunk.length++;
					}
				}
				
				if (!isPunct)
				{
					prevDirection = charDirection;
				}
			}
			
			counter++;
		}
		
		return chunkGroups;
	}
	
	// TODO: restore text coloring...
	// added support for autosized fields (if fieldWidth <= 0)
	public function layoutText(text:String, renderData:RenderData, fieldWidth:Float = 0.0, fontScale:Float = 1.0, letterSpacing:Float = 0.0, ?letterColors:Array<Int>):RenderData
	{
		if (text == null || text.length == 0)
		{
			return renderData;
		}
		
		var charCodes:Array<Int> = getCharCodes(text);
		var chunkGroups = preProcessText(charCodes);
		text = null;

		var renderList = renderData.renderList;
		var linesLength:Array<Int> = renderData.linesLength;
		var linesWidth:Array<Float> = renderData.linesWidth;
		var linesNumber:Int = 1;

		var lineXStart = (direction == LeftToRight) ? 0.0 : fieldWidth;
		var xPosBase:Float = lineXStart;
		var yPosBase:Float = linesNumber * lineHeight * fontScale;
		var lineWidth:Float = 0.0;
		var lineLength:Int = 0;

		renderData.colors = null;
		renderData.colored = false;
		var colorIndex = 0;

		/*if (letterColors != null)
		{
			renderData.colors = [];
			renderData.colored = true;
		}*/
		
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
				//	colorIndex++;
					
					continue;
				}

				var dstX = (xPos + (posInfo.offset.x + g.bitmapLeft) * fontScale);
				var dstY = (yPos + (posInfo.offset.y - g.bitmapTop) * fontScale);

				var avanceX = posInfo.advance.x / (100 / 64) * fontScale; // 100/64 = 1.5625 = Magic!
				var avanceY = posInfo.advance.y / (100 / 64) * fontScale;

				if (fieldWidth > 0 && xPos + avanceX >= fieldWidth && direction == LeftToRight) 
				{
					trace("push to linesWidth: " + (linesNumber - 1) + " " + lineWidth);
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
	
		for (group in chunkGroups)
		{
			var chunks = group.chunks;
			
			if (group.direction != direction)
			{
				var widthLeft:Float = (fieldWidth <= 0) ? 0 : fieldWidth - lineWidth;
				
				var line:Array<String> = [];
				var lines = [];
				lines.push(line);
				
				for (chunk in chunks)
				{
					var chunkWords = splitText(charCodes, chunk.start, chunk.length);
					
					for (word in chunkWords)
					{
						var renderedWord = OpenflHarbuzzCFFI.layoutText(face, OpenflHarbuzzCFFI.createBuffer(group.direction, chunk.script, language, word));
						var wordWidth = layoutWidth(renderedWord, fontScale, letterSpacing);

						if (word == "\n" || isEndOfLine2(0, wordWidth, widthLeft))
						{
							popSpaces(line);
							
							line = [];
							lines.push(line);
							widthLeft = (fieldWidth <= 0) ? 0 : fieldWidth;
							
							if (StringTools.isSpace(word, 0)) 
							{
								continue;
							}
						}
						
						line.push(word);
						
						widthLeft -= wordWidth;
						
						if (fieldWidth > 0 && widthLeft <= 0)
						{
							popSpaces(line);
							
							line = [];
							lines.push(line);
							widthLeft = (fieldWidth <= 0) ? 0 : fieldWidth;
						}
					}
				}
				
				for (line in lines)
				{
					var lineText = line.join("");
					var renderedLine = OpenflHarbuzzCFFI.layoutText(face, OpenflHarbuzzCFFI.createBuffer(group.direction, script, language, lineText));
					var renderedWidth = layoutWidth(renderedLine, fontScale, letterSpacing);
				
					if (isEndOfLine2(lineWidth, renderedWidth, fieldWidth))
					{
						linesNumber++;
						yPosBase = linesNumber * lineHeight * fontScale;
						xPosBase = 0;
						
						if (direction != LeftToRight) 
						{
							xPosBase = fieldWidth;
						}
					}
					
					pushToRenderList(lineText, renderedLine, renderedWidth);
				}
			}
			else
			{
				// just go further through the group and fill the lines...
				for (chunk in group.chunks)
				{
					var chunkWords = splitText(charCodes, chunk.start, chunk.length);
					
					for (word in chunkWords)
					{
						var renderedWord = OpenflHarbuzzCFFI.layoutText(face, OpenflHarbuzzCFFI.createBuffer(group.direction, chunk.script, language, word));
						var wordWidth = layoutWidth(renderedWord, fontScale, letterSpacing);

						if (word == "\n" || isEndOfLine(xPosBase, wordWidth, fieldWidth)) 
						{
							trace("push to linesWidth: " + (linesNumber - 1) + " " + lineWidth);
							
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
								continue;
							}
						}
						
						pushToRenderList(word, renderedWord, wordWidth);
					}
				}
			}
		}

		// flush everything that left
		trace("push to linesWidth: " + (linesNumber - 1) + " " + lineWidth);
		
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
		
		// TODO: fix lines widths and lengths...
		trace("linesNumber: " + linesNumber);
		for (i in 0...linesNumber)
		{
			trace("line " + i + " width: " + linesWidth[i]);
			trace("line " + i + " length: " + linesLength[i]);
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
