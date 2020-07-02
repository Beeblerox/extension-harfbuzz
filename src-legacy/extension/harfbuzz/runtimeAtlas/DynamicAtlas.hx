package extension.harfbuzz.runtimeAtlas;

import openfl.geom.Rectangle;

/**
 * Класс для генерации текстурных атласов
 * @author Zaphod
 */
class DynamicAtlas
{
	/**
	 * Root node of atlas
	 */
	public var root(default, null):Node;
	
	/**
	 * Distance (both horizontal and vertical) between nodes in atlas
	 */
	public var border(default, null):Int;
	
	/**
	 * Total width of atlas
	 */
	public var width(get, null):Int;
	
	/**
	 * Total height of atlas
	 */
	public var height(get, null):Int;
	
	/**
	 * Atlas constructor
	 * @param	width		atlas width
	 * @param	height		atlas height
	 * @param	border		distance (both horizontal and vertical) between nodes
	 */
	public function new(width:Int, height:Int, ?border:Int = 0) 
	{
		root = new Node(new Rectangle(0, 0, width, height), null, this);
		this.border = border;
	}
	
	/**
	 * Simply adds new node to atlas.
	 * 
	 * @return			added node
	 */
	public function addNode(dataWidth:Int, dataHeight:Int):Node
	{
		if (!root.canPlace(dataWidth, dataHeight))
		{
			return null;
		}
		
		var insertWidth:Int = (dataWidth == width) ? dataWidth : dataWidth + border;
		var insertHeight:Int = (dataHeight == height) ? dataHeight : dataHeight + border;
		
		var nodeToInsert:Node = findNodeToInsert(insertWidth, insertHeight);
		if (nodeToInsert != null)
		{
			var firstChild:Node;
			var secondChild:Node;
			var firstGrandChild:Node;
			var secondGrandChild:Node;
			
			var dw:Int = nodeToInsert.width - insertWidth;
			var dh:Int = nodeToInsert.height - insertHeight;
			
			if (dw > dh) // делим по горизонтали
			{
				firstChild = new Node(new Rectangle(nodeToInsert.x, nodeToInsert.y, insertWidth, nodeToInsert.height), nodeToInsert, this);
				secondChild = new Node(new Rectangle(nodeToInsert.x + insertWidth, nodeToInsert.y, nodeToInsert.width - insertWidth, nodeToInsert.height), nodeToInsert, this);
				
				firstGrandChild = new Node(new Rectangle(firstChild.x, firstChild.y, insertWidth, insertHeight), firstChild, this, true);
				secondGrandChild = new Node(new Rectangle(firstChild.x, firstChild.y + insertHeight, insertWidth, firstChild.height - insertHeight), firstChild, this);
			}
			else // делим по вертикали
			{
				firstChild = new Node(new Rectangle(nodeToInsert.x, nodeToInsert.y, nodeToInsert.width, insertHeight), nodeToInsert, this);
				secondChild = new Node(new Rectangle(nodeToInsert.x, nodeToInsert.y + insertHeight, nodeToInsert.width, nodeToInsert.height - insertHeight), nodeToInsert, this);
				
				firstGrandChild = new Node(new Rectangle(firstChild.x, firstChild.y, insertWidth, insertHeight), firstChild, this, true);
				secondGrandChild = new Node(new Rectangle(firstChild.x + insertWidth, firstChild.y, firstChild.width - insertWidth, insertHeight), firstChild, this);
			}
			
			firstChild.left = firstGrandChild;
			firstChild.right = secondGrandChild;
			
			nodeToInsert.left = firstChild;
			nodeToInsert.right = secondChild;
			
			return firstGrandChild;
		}
		
		return null;
	}
	
	/**
	 * Destroys atlas. Use only if you want to clear memory and don't need that atlas anymore
	 */
	public function cleanup():Void
	{
		clear();
		root = null;
	}
	
	/**
	 * Clears all data in atlas. Use it when you want reuse this atlas
	 */
	public function clear():Void
	{
		freeNode(root);
	}
	
	public function freeNode(node:Node):Void
	{
		if (node != null)
		{
			var parent = node.parent;
			if (parent != null)
			{
				var otherChild:Node = (parent.left == node) ? parent.right : parent.left;
				if ((otherChild == null) || (otherChild != null && !otherChild.filled))
				{
					parent.left = null;
					parent.right = null;
					parent.filled = false;
				}
			}
			
			freeNodeChildren(node);
		}
	}
	
	private function freeNodeChildren(node:Node):Void
	{
		if (node.left != null) freeNodeChildren(node.left);
		if (node.right != null) freeNodeChildren(node.right);
		node.cleanup();
	}
	
	// Внутренний итератор для нисходящего обхода в глубину, использующий стек для хранения информации об еще не пройденных поддеревьях
	private function findNodeToInsert(insertWidth:Int, insertHeight:Int):Node
	{
		// Стек для хранения узлов
		var stack:Array<Node> = [];
		// Текущий узел
		var current:Node = root;
		// Основной цикл
		while (true)
		{
			// Обходим текущий узел дерева
			if (current.isEmpty && current.canPlace(insertWidth, insertHeight))
			{
				return current;
			}
			
			// Переходим к следующему узлу
			if (current.right != null && current.right.canPlace(insertWidth, insertHeight) && current.left != null && current.left.canPlace(insertWidth, insertHeight))
			{
				stack.push(current.right);
				current = current.left;
			}
			else if (current.left != null && current.left.canPlace(insertWidth, insertHeight))
			{
				current = current.left;
			}
			else if (current.right != null && current.right.canPlace(insertWidth, insertHeight))
			{
				current = current.right;
			}
			else
			{
				if (stack.length > 0)
				{
					// Пытаемся извлечь очередную вершину из стека
					current = stack.pop();
				}
				else
				{
					// Стек пуст, заканчиваем работу цикла и функции
					return null;
				}
			}
		}
		
		return null;
	}
	
	private inline function get_width():Int
	{
		return root.width;
	}
	
	public inline function get_height():Int
	{
		return root.height;
	}
}