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

// TODO (Zaphod): use it...
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
	
	var words:Array<String>; // null by default...
	var width:Float = 0.0;
	
	function new()
	{
		
	}
}

// todo (zaphod): spaces text chunk???

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

	private function isSpace(i:Int)
	{
		return (i > 8 && i < 14) || i == 32;
	}
	
	

	// Splits text into words containging the trailing spaces ("a b c"=["a ", "b ", "c "])
	function split(text:String, letterColors:Array<Int>, resColors:Array<Int>):Array<String> 
	{
		var ret = [];
		var currentWord:Utf8 = null;
		var l:Int = Utf8.length(text);
		
		var genColors:Bool = (letterColors.length > 0);
		var currentWordColors:Array<Int> = null;
		var colorIndex:Int = -1;
		
		Utf8.iter(text, function(cCode:Int)
		{
			colorIndex++;
			
			if (cCode == 13) return;
			if (isSpace(cCode)) 
			{
				if (currentWord != null) 
				{
					ret.push(currentWord.toString());
					
					if (genColors)
					{
						addColorsFrom(resColors, currentWordColors);
					}
				}
				
				currentWord = new Utf8();
				currentWord.addChar(cCode);
				ret.push(currentWord.toString());
				currentWord = null;
				
				if (genColors)
				{
					currentWordColors = [];
					addColor(currentWordColors, letterColors[colorIndex]);
					addColorsFrom(resColors, currentWordColors);
					currentWordColors = null;
				}
				
				return;
			}
			
			if (currentWord == null) 
			{
				currentWord = new Utf8();
				
				if (genColors)
				{
					currentWordColors = [];
				}
			}
			
			currentWord.addChar(cCode);
			
			if (genColors)
			{
				addColor(currentWordColors, letterColors[colorIndex]);
			}
		});
		if (currentWord != null) 
		{
			ret.push(currentWord.toString());
			
			if (genColors)
			{
				addColorsFrom(resColors, currentWordColors);
			}
		}
		
		return ret;
	}
	
	function splitText(text:String):Array<String> 
	{
		var ret = [];
		var currentWord:Utf8 = null;
		var l:Int = Utf8.length(text);
		
		Utf8.iter(text, function(cCode:Int)
		{
			if (cCode == 13) return;
			if (isSpace(cCode)) 
			{
				if (currentWord != null) 
				{
					ret.push(currentWord.toString());
				}
				
				currentWord = new Utf8();
				currentWord.addChar(cCode);
				ret.push(currentWord.toString());
				currentWord = null;
				
				return;
			}
			
			if (currentWord == null) 
			{
				currentWord = new Utf8();
			}
			
			currentWord.addChar(cCode);
		});
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

	private function invertString(s:String):String
	{
		var l:Int = Utf8.length(s);
		var res:Utf8 = new Utf8();
		for (i in -l + 1...1) res.addChar(Utf8.charCodeAt(s, -i));
		return res.toString();
	}
	
	private inline function invertArray(arr:Array<Int>):Array<Int>
	{
		var l:Int = arr.length;
		var res:Array<Int> = [];
		for (i in (-l + 1)...1) res.push(arr[-i]);
		return res;
	}
	
	private function addColorsFrom(to:Array<Int>, from:Array<Int>):Void
	{
		for (i in 0...from.length)
		{
			to.push(from[i]);
		}
	}
	
	private function addColor(to:Array<Int>, color:Int):Void
	{
		to.push(color);
	}

	// if "text" is in RtoL script, invert non-RtoL substrings
	function preProcessText(text:String, letterColors:Array<Int>, resColors:Array<Int>) 
	{
		var isRtoL:Bool = TextScriptTools.isRightToLeft(script);
		var res:StringBuf = new StringBuf();
		var char:String = '';
		var charCode:Int;
		var phrase:String = '';
		var spaces:String = '';
		var word:String = '';
		var length:Int = Utf8.length(text);

		var genColors:Bool = (letterColors != null && resColors != null);
		var charColor:Int = 0xffffff;
		var spacesColors:Array<Int> = [];
		var wordColors:Array<Int> = [];
		var phraseColors:Array<Int> = [];
		
		
		
		
		
		var chunkStart:Int = 0;
		charCode = Utf8.charCodeAt(text, chunkStart);
		var currentScript:TextScript = ScriptIdentificator.getCharCodeScript(charCode);
		var currentDirection:TextDirection = TextScriptTools.isRightToLeft(currentScript) ? TextDirection.RightToLeft : TextDirection.LeftToRight;
		var prevDirection:TextDirection = currentDirection;
		
		trace("currentDirection: " + currentDirection + "; prevDirection: " + prevDirection);
	
		// TODO (Zaphod): use it!!!
		var spacesChunk:TextChunk = new TextChunk();
		var chunk:TextChunk = new TextChunk();
		
		/*if (isSpace(charCode))
		{
			spacesChunk.start = chunkStart;
			spacesChunk.script = currentScript;
			spacesChunk.length = 1;
		}
		else*/
		{
			chunk.start = chunkStart;
			chunk.script = currentScript;
			chunk.length = 1;
		}
		
		var chunks:Array<TextChunk> = [chunk];
		
		var currentGroup:ChunkGroup = new ChunkGroup();
		currentGroup.direction = currentDirection;
		currentGroup.chunks = chunks;
		
		chunkGroups = [];
		chunkGroups.push(currentGroup);
		
	//	var spacesChunk:TextChunk = new TextChunk();
	
		// если справа или слева от последовательности пробелов имеем RTL текст, то выделяем последовательность пробелов в отдельную группу и добавляем ее в RTL группу...
		
		var prevDirection:TextDirection = currentDirection;
		
		
		var numSpaces:Int = isSpace(charCode) ? 1 : 0;
		var counter:Int = 1;
		while (counter < length)
		{
			charCode = Utf8.charCodeAt(text, counter);
			var charScript = ScriptIdentificator.getCharCodeScript(charCode);
			var charDirection:TextDirection = TextScriptTools.isRightToLeft(charScript) ? TextDirection.RightToLeft : TextDirection.LeftToRight;
			
			if (isSpace(charCode))
			{
				numSpaces++;
				
			}
			else
			{
				
				
				numSpaces = 0;
			}
			
			counter++;
		}
		
		for (i in 1...length)
		{
			charCode = Utf8.charCodeAt(text, i);
			var charScript = ScriptIdentificator.getCharCodeScript(charCode);
			var charDirection:TextDirection = TextScriptTools.isRightToLeft(charScript) ? TextDirection.RightToLeft : TextDirection.LeftToRight;
			
		//	trace("charCode: " + charCode + ", pos: " + i + ", charScript: " + charScript + ", charDirection: " + charDirection);
			
			if (!isSpace(charCode) && (charDirection != prevDirection) && (charDirection != TextDirection.LeftToRight || prevDirection != TextDirection.LeftToRight))
			{
		//		trace("charDirection: " + charDirection + "; prevDirection: " + prevDirection + ", charCode: " + charCode + ", pos: " + i);
				
				chunks = [];
				
				
				chunkStart = i;
				currentScript = charScript;
				
				chunk = new TextChunk();
				chunk.start = chunkStart;
				chunk.script = currentScript;
				chunk.length = 1;
				
		//		trace("new TextChunk");
				
				chunks.push(chunk);
				
				
				currentGroup = new ChunkGroup();
				currentGroup.direction = charDirection;
				currentGroup.chunks = chunks;
				
				chunkGroups.push(currentGroup);
				
				currentDirection = charDirection;
				prevDirection = charDirection;
			}
			else
			{
				chunk.length++;
			}
				
				
			}
			
			if (!isSpace(charCode))
			{
				prevDirection = charDirection;
			}
			
		}
		
		
		
		
		
		/*var chunkStart:Int = 0;
		charCode = Utf8.charCodeAt(text, 0);
		var currentScript:TextScript = ScriptIdentificator.getCharCodeScript(charCode);
		
		var currentDirection:TextDirection = TextScriptTools.isRightToLeft(currentScript) ? TextDirection.RightToLeft : TextDirection.LeftToRight;
		
		var chunks:Array<TextChunk> = [];
	
		var currentGroup:ChunkGroup = new ChunkGroup();
		currentGroup.direction = currentDirection;
		currentGroup.chunks = chunks;
		
		chunkGroups = [];
		chunkGroups.push(currentGroup);
		
	//	var spacesChunk:TextChunk = new TextChunk();
	
		// если справа или слева от последовательности пробелов имеем RTL текст, то выделяем последовательность пробелов в отдельную группу...
		
		var prevDirection:TextDirection = currentDirection;
		
		for (i in 1...length)
		{
			charCode = Utf8.charCodeAt(text, i);
			var charScript = ScriptIdentificator.getCharCodeScript(charCode);
			var charDirection:TextDirection = TextScriptTools.isRightToLeft(charScript) ? TextDirection.RightToLeft : TextDirection.LeftToRight;
			
			if (isSpace(charCode))
			{
				if (charDirection != currentDirection) // RTL text case
				{
					
					
					
				}
				else
				{
					
				}
			}
			else
			{
				
			}
			
		//	if (!isSpace(charCode))
			{
				if (charScript != currentScript) // "10" is the new line char
				{
					var chunk:TextChunk = new TextChunk();
					chunk.start = chunkStart;
					chunk.length = i - chunkStart;
					chunk.script = currentScript;
					
					chunks.push(chunk);
					
					chunkStart = i;
					currentScript = charScript;
				}
				
				if (charDirection != currentDirection)
				{
					chunks = [];
					
					currentGroup = new ChunkGroup();
					currentGroup.direction = charDirection;
					currentGroup.chunks = chunks;
					
					chunkGroups.push(currentGroup);
					
					currentDirection = charDirection;
				}
			}
			
			
		}

		if (chunkStart <= length - 1)
		{
			var chunk:TextChunk = new TextChunk();
			chunk.start = chunkStart;
			chunk.length = length - chunkStart;
			chunk.script = currentScript;
			
			chunks.push(chunk);
		}*/
		
		for (i in 0...length)
		{
			char = Utf8.sub(text, i, 1);
			charCode = Utf8.charCodeAt(text, i);
			
			if (genColors) 
			{
				charColor = letterColors[i];
			}
			
			if (char == "\r") continue;
			if (isPunctuation(char) || isSpace(charCode)) 
			{
				if (word == '') 
				{
					spaces += char;
					
					if (genColors) 
					{
						addColor(spacesColors, charColor);
					}
					
					continue;
				}
				
				if (char == "\n" || TextScriptTools.isRightToLeft(ScriptIdentificator.identify(word, script)) == isRtoL)
				{
					res.add(invertString(phrase));
					res.add(spaces);
					res.add(word);
					res.add(char);
					
					spaces = phrase = word = '';
					
					if (genColors) 
					{
						addColorsFrom(resColors, invertArray(phraseColors));
						addColorsFrom(resColors, spacesColors);
						addColorsFrom(resColors, wordColors);
						addColor(resColors, charColor);
						
						spacesColors = [];
						phraseColors = [];
						wordColors = [];
					}
				} 
				else 
				{
					if (phrase == '') 
					{
						res.add(spaces);
						spaces = '';
						
						if (genColors) 
						{
							addColorsFrom(resColors, spacesColors);
							spacesColors = [];
						}
					}
					
					phrase += spaces + word;
					word = '';
					spaces = char;
					
					if (genColors) 
					{
						addColorsFrom(phraseColors, spacesColors);
						addColorsFrom(phraseColors, wordColors);
						wordColors = [];
						spacesColors = [charColor];
					}
				}
				
				continue;
			}
			
			word += char;
			
			if (genColors) 
			{
				addColor(wordColors, charColor);
			}
		}

		if (word != '' && TextScriptTools.isRightToLeft(ScriptIdentificator.identify(word, script)) != isRtoL) 
		{
			phrase += spaces + word;
			spaces = word = '';
			
			if (genColors) 
			{
				addColorsFrom(phraseColors, spacesColors);
				addColorsFrom(phraseColors, wordColors);
				spacesColors = [];
				wordColors = [];
			}
		}
		
		res.add(invertString(phrase));
		res.add(spaces);
		res.add(word);
		
		if (genColors) 
		{
			addColorsFrom(resColors, invertArray(phraseColors));
			addColorsFrom(resColors, spacesColors);
			addColorsFrom(resColors, wordColors);
		}
		
		return res.toString();
	}
	
	// added support for autosized fields (if fieldWidth <= 0)
	public function layoutText(text:String, renderData:RenderData, fieldWidth:Float = 0.0, fontScale:Float = 1.0, letterSpacing:Float = 0.0, ?letterColors:Array<Int>):RenderData
	{
		var original = text;
		var preprocessedColors:Array<Int> = [];
		text = preProcessText(text, letterColors, preprocessedColors);

		var renderList = renderData.renderList;
		var linesLength:Array<Int> = renderData.linesLength;
		var linesWidth:Array<Float> = renderData.linesWidth;
		var linesNumber:Int = 1;

		var splitColors:Array<Int> = [];
		var words = split(text, preprocessedColors, splitColors);

		var lineXStart = (direction == LeftToRight) ? 0.0 : fieldWidth;
		var xPosBase:Float = lineXStart;
		var yPosBase:Float = linesNumber * lineHeight * fontScale;
		var lineWidth:Float = 0.0;
		var lineLength:Int = 0;

		renderData.colors = null;
		renderData.colored = false;
		var colorIndex = 0;

		if (letterColors != null)
		{
			renderData.colors = [];
			renderData.colored = true;
		}
		
		var chunkIndex:Int = 0;
		
	//	trace("new line code: " + "\n".charCodeAt(0)); // 10
	
		var lineGroups:Array<ChunkGroup> = [];
	
		for (group in chunkGroups)
		{
			var chunks = group.chunks;
			
			var chunkIndex:Int = 0;
			var wordIndex:Int = 0;
			
			if (group.direction != direction)
			{
				var widthLeft:Float = (fieldWidth <= 0) ? 0 : fieldWidth - lineWidth;
				
				var line:Array<String> = [];
				var lines = [];
				lines.push(line);
				
				for (chunk in chunks)
				{
					var chunkText:String = Utf8.sub(original, chunk.start, chunk.length);
					chunk.words = splitText(chunkText);
					
					for (word in chunk.words)
					{
						var renderedWord = OpenflHarbuzzCFFI.layoutText(face, OpenflHarbuzzCFFI.createBuffer(group.direction, chunk.script, language, word));
						var wordWidth = layoutWidth(renderedWord, fontScale, letterSpacing);
						
						/*if (StringTools.isSpace(word, 0) && line.length == 0) 
						{
							continue;
						}*/
						
						if (word == "\n" || isEndOfLine2(0, wordWidth, widthLeft)) // TODO (Zaphod): make it better...
						{
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
							line = [];
							lines.push(line);
							widthLeft = (fieldWidth <= 0) ? 0 : fieldWidth;
						}
					}
				}
				
			//	trace("lines: " + lines);
				
				for (line in lines)
				{
					var lineText = line.join("");
					
				//	trace("lineText: " + lineText);
					
					var renderedLine = OpenflHarbuzzCFFI.layoutText(face, OpenflHarbuzzCFFI.createBuffer(group.direction, script, language, lineText));
					var renderedWidth = layoutWidth(renderedLine, fontScale, letterSpacing);
					
				//	trace("chunk start: " + chunk.start + ", length: " + chunk.length + ", script: " + chunk.script + ", direction: " + chunkDirection);
				//	trace("chunk text: " + chunkText);
				//	trace("chunk width: " + chunkWidth);
				
					if (fieldWidth > 0 && lineWidth + renderedWidth >= fieldWidth)
					{
						linesNumber++;
						yPosBase = linesNumber * lineHeight * fontScale;
						xPosBase = 0;
						
						if (direction != LeftToRight) 
						{
							xPosBase = fieldWidth;
						}
					}
					
				
					var xPos = xPosBase;
					if (direction == RightToLeft) xPos -= renderedWidth;
					var yPos = yPosBase;
					
				//	trace("xPos: " + xPos);
				//	trace("renderedWidth: " + renderedWidth);
					
					
					
					for (posInfo in renderedLine) 
					{
						var g = renderer.glyphs[posInfo.codepoint];
						if (g == null)
						{
							renderer.addGlyphs(OpenflHarbuzzCFFI.createGlyphData(face, OpenflHarbuzzCFFI.createBuffer(group.direction, script, language, lineText)));
						}
						
						g = renderer.glyphs[posInfo.codepoint];
						if (g == null) 
						{
		#if debug
					//		trace("WOW! I'm missing a glyph for the following word: " + word);
					//		trace("This should not be happening! Your text will be renderer badly :(");
					//		trace("CODEPINT " + posInfo.codepoint);
					//		trace(posInfo);
		#end
						//	colorIndex++;
							
							continue;
						}

						var dstX = (xPos + (posInfo.offset.x + g.bitmapLeft) * fontScale);
						var dstY = (yPos + (posInfo.offset.y - g.bitmapTop) * fontScale);

						var avanceX = posInfo.advance.x / (100 / 64) * fontScale; // 100/64 = 1.5625 = Magic!
						var avanceY = posInfo.advance.y / (100 / 64) * fontScale;

						renderList.push(new RenderItem(g.codepoint, dstX, dstY));
						lineLength++;

						xPos += avanceX + letterSpacing;
						yPos += avanceY;
					}
					
					lineWidth += renderedWidth;
					if (direction == LeftToRight) 
					{
						xPosBase += renderedWidth;
					} 
					else 
					{
						xPosBase -= renderedWidth;
					}
					
					/*if (fieldWidth > 0 && lineWidth >= fieldWidth)
					{
						linesNumber++;
						yPosBase = linesNumber * lineHeight * fontScale;
						xPosBase = 0;
						
						if (direction != LeftToRight) 
						{
							xPosBase = fieldWidth;
						}
					}*/
					
				//	

				}
			}
			else
			{
				// just go further through the group and fill the lines...
				for (chunk in group.chunks)
				{
					var chunkText:String = Utf8.sub(original, chunk.start, chunk.length);
					chunk.words = splitText(chunkText);
					
					for (word in chunk.words)
					{
						var renderedWord = OpenflHarbuzzCFFI.layoutText(face, OpenflHarbuzzCFFI.createBuffer(group.direction, chunk.script, language, word));
						var wordWidth = layoutWidth(renderedWord, fontScale, letterSpacing);

						if (word == "\n" || isEndOfLine(xPosBase, wordWidth, fieldWidth)) 
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
								continue;
							}
						}

						var xPos = xPosBase;
						if (direction == RightToLeft) xPos -= wordWidth;
						var yPos = yPosBase;

						for (posInfo in renderedWord) 
						{
							var g = renderer.glyphs[posInfo.codepoint];
							if (g == null)
							{
								renderer.addGlyphs(OpenflHarbuzzCFFI.createGlyphData(face, createBuffer(word)));
							}
							
							g = renderer.glyphs[posInfo.codepoint];
							if (g == null) 
							{
			#if debug
								trace("WOW! I'm missing a glyph for the following word: " + word);
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

							xPos += avanceX + letterSpacing;
							yPos += avanceY;
						}

						if (direction == LeftToRight) 
						{
							xPosBase += wordWidth;
						} 
						else 
						{
							xPosBase -= wordWidth;
						}
						
						lineWidth += wordWidth;

					}
				}
			}
		}
		
		/*for (group in chunkGroups)
		{
			var chunks = group.chunks;
			
			trace("group chunks: " + chunks.length + " direction: " + group.direction);
			
			for (chunk in chunks)
			{
				var chunkText:String = Utf8.sub(original, chunk.start, chunk.length);
				var chunkDirection = group.direction;
				
				var renderedChunk = OpenflHarbuzzCFFI.layoutText(face, OpenflHarbuzzCFFI.createBuffer(chunkDirection, chunk.script, language, chunkText));
				
				var chunkWidth = layoutWidth(renderedChunk, fontScale, letterSpacing);
				
			//	trace("chunk start: " + chunk.start + ", length: " + chunk.length + ", script: " + chunk.script + ", direction: " + chunkDirection);
			//	trace("chunk text: " + chunkText);
			//	trace("chunk width: " + chunkWidth);
				
				var xPos = 10.0;
				var yPos = chunkIndex * 30.0 + 10.0;

				for (posInfo in renderedChunk) 
				{
					var g = renderer.glyphs[posInfo.codepoint];
					if (g == null)
					{
						renderer.addGlyphs(OpenflHarbuzzCFFI.createGlyphData(face, OpenflHarbuzzCFFI.createBuffer(chunkDirection, chunk.script, language, chunkText)));
					}
					
					g = renderer.glyphs[posInfo.codepoint];
					if (g == null) 
					{
	#if debug
				//		trace("WOW! I'm missing a glyph for the following word: " + word);
				//		trace("This should not be happening! Your text will be renderer badly :(");
				//		trace("CODEPINT " + posInfo.codepoint);
				//		trace(posInfo);
	#end
						colorIndex++;
						
						continue;
					}

					var dstX = (xPos + (posInfo.offset.x + g.bitmapLeft) * fontScale);
					var dstY = (yPos + (posInfo.offset.y - g.bitmapTop) * fontScale);

					var avanceX = posInfo.advance.x / (100 / 64) * fontScale; // 100/64 = 1.5625 = Magic!
					var avanceY = posInfo.advance.y / (100 / 64) * fontScale;

					renderList.push(new RenderItem(g.codepoint, dstX, dstY));
					lineLength++;

					xPos += avanceX + letterSpacing;
					yPos += avanceY;
				}
				
				chunkIndex++;
			}
		}*/


		/*for (word in words) 
		{
			var renderedWord = OpenflHarbuzzCFFI.layoutText(face, createBuffer(word));
			var wordWidth = layoutWidth(renderedWord, fontScale, letterSpacing);
			
			var wordLength:Int = Utf8.length(word);
			var renderedWordLength:Int = renderedWord.length;

			if (word == "\n" || isEndOfLine(xPosBase, wordWidth, fieldWidth)) 
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
					colorIndex += wordLength;
					
					continue;
				}
			}

			var xPos = xPosBase;
			if (direction == RightToLeft) xPos -= wordWidth;
			var yPos = yPosBase;

			for (posInfo in renderedWord) 
			{
				var g = renderer.glyphs[posInfo.codepoint];
				if (g == null)
				{
					renderer.addGlyphs(OpenflHarbuzzCFFI.createGlyphData(face, createBuffer(word)));
				}
				
				g = renderer.glyphs[posInfo.codepoint];
				if (g == null) 
				{
#if debug
					trace("WOW! I'm missing a glyph for the following word: " + word);
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

				xPos += avanceX + letterSpacing;
				yPos += avanceY;
				
				if (renderData.colored)
				{
					renderData.colors.push(splitColors[colorIndex]);
					colorIndex++;
				}
			}

			if (direction == LeftToRight) 
			{
				xPosBase += wordWidth;
			} 
			else 
			{
				xPosBase -= wordWidth;
			}
			
			lineWidth += wordWidth;
		}*/

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
