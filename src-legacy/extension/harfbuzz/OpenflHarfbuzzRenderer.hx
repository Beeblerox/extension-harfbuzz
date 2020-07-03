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
	
	public function new()
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
			#if (!openfl_next)
			face = OpenflHarbuzzCFFI.loadFontFaceFromMemory(getBytes(fontName).getData());
			#else
			face = OpenflHarbuzzCFFI.loadFontFaceFromMemory(getBytes(fontName));
			#end
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
		return i==9 || i==10 || i==11 || i==12 || i==13 || i==32;
	}

	// Splits text into words containging the trailing spaces ("a b c"=["a ", "b ", "c "])
	function split(text:String) : Array<String> 
	{
		var ret = [];
		var currentWord:Utf8 = null;
		var l:Int = Utf8.length(text);
		Utf8.iter(text, function(cCode:Int)
		{
			if (cCode == 13) return;
			if (isSpace(cCode)) 
			{
				if (currentWord != null) ret.push(currentWord.toString());
				currentWord = new Utf8();
				currentWord.addChar(cCode);
				ret.push(currentWord.toString());
				currentWord = null;
				return;
			}
			
			if (currentWord == null) currentWord = new Utf8();
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

	private function invertString(s:String):String
	{
		var l:Int = Utf8.length(s);
		var res:Utf8 = new Utf8();
		for (i in -l + 1...1) res.addChar(Utf8.charCodeAt(s, -i));
		return res.toString();
	}

	// if "text" is in RtoL script, invert non-RtoL substrings
	function preProcessText(text:String) 
	{
		var isRtoL:Bool = TextScriptTools.isRightToLeft(script);
		var res:StringBuf = new StringBuf();
		var char:String = '';
		var phrase:String = '';
		var spaces:String = '';
		var word:String = '';
		var length:Int = Utf8.length(text);

		for (i in 0...length)
		{
			char = Utf8.sub(text, i, 1);
			if (char=="\r") continue;
			if (isPunctuation(char) || StringTools.isSpace(text, i)) 
			{
				if (word == '') 
				{
					spaces += char;
					continue;
				}
				if (char == "\n" || TextScriptTools.isRightToLeft(ScriptIdentificator.identify(word, script)) == isRtoL)
				{
					res.add(invertString(phrase));
					res.add(spaces);
					res.add(word);
					res.add(char);
					spaces = phrase = word = '';
				} 
				else 
				{
					if (phrase == '') 
					{
						res.add(spaces);
						spaces = '';
					}
					
					phrase += spaces+word;
					word = '';
					spaces = char;
				}
				
				continue;
			}
			
			word += char;
		}

		if (word != '' && TextScriptTools.isRightToLeft(ScriptIdentificator.identify(word, script)) != isRtoL) 
		{
			phrase += spaces + word;
			spaces = word = '';
		}
		res.add(invertString(phrase));
		res.add(spaces);
		res.add(word);
		return res.toString();
	}
	
	// added support for autosized fields (if fieldWidth <= 0)
	public function layoutText(text:String, renderData:RenderData, fieldWidth:Float = 0.0, fontScale:Float = 1.0, letterSpacing:Float = 0.0):RenderData
	{
		text = preProcessText(text);

		var renderList = renderData.renderList;
		var linesLength:Array<Int> = renderData.linesLength;
		var linesWidth:Array<Float> = renderData.linesWidth;
		var linesNumber:Int = 1;

		var words = split(text);

		var lineXStart = (direction == LeftToRight) ? 0.0 : fieldWidth;
		var xPosBase:Float = lineXStart;
		var yPosBase:Float = linesNumber * lineHeight * fontScale;
		var lineWidth:Float = 0.0;
		var lineLength:Int = 0;

		for (word in words) 
		{
			var renderedWord = OpenflHarbuzzCFFI.layoutText(face, createBuffer(word));
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
				if (StringTools.isSpace(word, 0)) continue;
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
					continue;
				}

				var dstX = /*Std.int*/(xPos + (posInfo.offset.x + g.bitmapLeft) * fontScale);
				var dstY = /*Std.int*/(yPos + (posInfo.offset.y - g.bitmapTop) * fontScale);

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
					dstX = /*Std.int*/(xPos + (posInfo.offset.x + g.bitmapLeft) * fontScale);
					dstY = /*Std.int*/(yPos + (posInfo.offset.y - g.bitmapTop) * fontScale);

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
	//	layoutText(text, 0.5, lineWidth, renderData);
		layoutText(text, renderData, lineWidth, 1.0, 0.0);
		
		/*trace("renderData.linesNumber: " + renderData.linesNumber);
		trace("renderData.linesLength: " + renderData.linesLength);
		trace("renderData.linesWidth: " + renderData.linesWidth);*/
		
		return renderer.render(lineWidth, renderData.linesNumber * lineHeight, renderData.renderList);
	}
}
