package extension.harfbuzz.runtimeAtlas;

import openfl.geom.Rectangle;

/**
 * Atlas Node holds some data and it's position on atlas
 * @author Zaphod
 */
class Node
{
	public var left:Node;
	public var right:Node;
	
	public var rect(default, null):Rectangle;
	public var packer(default, null):DynamicAtlas;
	
	public var parent:Node;
	
	public var filled:Bool;
	
	public var x(get, null):Int;
	public var y(get, null):Int;
	public var width(get, null):Int;
	public var height(get, null):Int;
	
	public var isEmpty(get, null):Bool;
	
	public function new(rect:Rectangle, parent:Node, packer:DynamicAtlas, filled:Bool = false) 
	{
		this.rect = rect;
		this.parent = parent;
		this.packer = packer;
		this.filled = filled;
		this.left = null;
		this.right = null;
	}
	
	public inline function canPlace(width:Int, height:Int):Bool
	{
		return (rect.width >= width && rect.height >= height);
	}
	
	public function cleanup():Void
	{
		left = null;
		right = null;
		parent = null;
		filled = false;
		packer = null;
	}
	
	private inline function get_isEmpty():Bool
	{
		return (!filled && left == null && right == null);
	}
	
	private inline function get_x():Int
	{
		return Std.int(rect.x);
	}
	
	private inline function get_y():Int
	{
		return Std.int(rect.y);
	}
	
	private inline function get_width():Int
	{
		return Std.int(rect.width);
	}
	
	private inline function get_height():Int
	{
		return Std.int(rect.height);
	}
}