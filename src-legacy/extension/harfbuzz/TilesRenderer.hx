package extension.harfbuzz;

import extension.harfbuzz.OpenflHarbuzzCFFI;
import extension.harfbuzz.OpenflHarbuzzCFFI.GlyphRect;
import extension.harfbuzz.runtimeAtlas.DynamicAtlas;
import extension.harfbuzz.runtimeAtlas.Node;
import openfl.display.BitmapData;
import openfl.display.Graphics;
import openfl.display.Sprite;
import openfl.display.Tilesheet;
import openfl.geom.Rectangle;

@:publicFields
class RenderItem
{
	var codepoint:Int;
	var x:Float;
	var y:Float;
	
	public function new(codepoint:Int = 0, x:Float = 0.0, y:Float = 0.0)
	{
		this.codepoint = codepoint;
		this.x = x;
		this.y = y;
	}
}

class TilesRenderer 
{
	public var glyphs(default, null):Map<Int, GlyphRect>;
	public var tilesheet(default, null):Tilesheet;
	public var glyphIds(default, null):Map<Int, Int>;	// Codepoint -> tile id
	
	var atlas:DynamicAtlas;
	var atlasBmp:BitmapData;
	var blitList:Array<Float>;
	
	var numGlyphs:Int = 0;
	
	var color:Int;
	
	public function new(glyphData:GlyphData, size:Int = 1024, color:Int = 0x0)
	{
		atlasBmp = new BitmapData(size, size);
		tilesheet = new Tilesheet(atlasBmp);
		atlas = new DynamicAtlas(size, size, 2);
		
	//	openfl.Lib.current.stage.addChild(new nme.display.Bitmap(atlasBmp));
		
		glyphs = new Map();
		glyphIds = new Map();
		blitList = [];
		
		this.color = color;
		
		addGlyphs(glyphData);
	}
	
	public function addGlyphs(glyphData:GlyphData)
	{
		var ct = new openfl.geom.ColorTransform(
			((color >> 16) & 0xff) / 255.0,
			((color >> 8) & 0xff) / 255.0,
			(color & 0xff) / 255.0,
			1, 0, 0, 0, 0);
		
		for (glyph in glyphData.glyphData)
		{
			var glyphRect = glyph.glyphRect;
			
			if (glyphs[glyphRect.codepoint] != null) // don't add dublicates...
			{
				continue;
			}
			
			var node:Node = atlas.addNode(glyphRect.width, glyphRect.height);
			var bmp = new BitmapData(glyphRect.width, glyphRect.height, true, 0x0);
			var rect = new Rectangle(0, 0, bmp.width, bmp.height);
			bmp.setVector(rect, glyph.bmpData);
			bmp.colorTransform(rect, ct);
			
			atlasBmp.copyPixels(bmp, rect, new openfl.geom.Point(node.x, node.y));
			
			glyphRect.x = node.x;
			glyphRect.y = node.y;
			
			var rect = new Rectangle(glyphRect.x, glyphRect.y, glyphRect.width, glyphRect.height);
			glyphs.set(glyphRect.codepoint, glyphRect);
			glyphIds.set(glyphRect.codepoint, numGlyphs++);
			tilesheet.addTileRect(rect);
		}
	}

	public function render(
		textWidth:Float,
		textHeight:Float,
		glyphList:Array<RenderItem>):HarfbuzzSprite 
	{
		blitList = [];
		
		var minY:Float = 5000000;
		var minX:Float = 5000000;
		var maxY:Float =-5000000;
		var maxX:Float =-5000000;
		
		for (g in glyphList) 
		{
			blitList.push(g.x);
			blitList.push(g.y);
			blitList.push(glyphIds[g.codepoint]);
		//	blitList.push(0.5);
			blitList.push(1);
			blitList.push(1);
			blitList.push(1);
			var rect = glyphs[g.codepoint];
			if (minY > g.y) minY = g.y;
			if (minX > g.x) minX = g.x;
			if (maxY < g.y + rect.height) maxY = g.y + rect.height;
			if (maxX < g.x + rect.width) maxX = g.x + rect.width;
		}

		var spr = new HarfbuzzSprite(textWidth, textHeight + minY, minX, minY, maxX, maxY);
		tilesheet.drawTiles(spr.graphics, blitList, true, Graphics.TILE_RGB /*| Graphics.TILE_SCALE*/);
		return spr;
	}
}
