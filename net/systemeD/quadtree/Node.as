package net.systemeD.quadtree {

	public class Node {
		
		public var bounds:Object;
		protected var children:Array;
		protected var nodes:Array;
		protected var _maxChildren:Number;
		protected var _depth:uint;
		protected var _maxDepth:uint;

		protected static const TOP_LEFT:uint = 0;
		protected static const TOP_RIGHT:uint = 1;
		protected static const BOTTOM_LEFT:uint = 2;
		protected static const BOTTOM_RIGHT:uint = 3;

		public function Node(bounds:Object, depth:uint=0, maxDepth:uint=4, maxChildren:Number=4) {
			this.bounds = bounds;
			children = [];
			nodes = [];
	
			_maxChildren = maxChildren;
			_maxDepth = maxDepth;
			_depth = depth;
		}

		public function insert(item:Object):void {
			if (nodes.length) {
				nodes[findIndex(item)].insert(item);
				return;
			}

			children.push(item);
			var len:Number=children.length;

			if(!(_depth>=_maxDepth) && len>_maxChildren) {
				subdivide();
				for (var i:Number=0; i<len; i++) { insert(children[i]); }
				children.length=0;
			}
		}
		
		public function retrieve(item:Object):Array {
			if (nodes.length) {
				return nodes[findIndex(item)].retrieve(item);
			}
			return children;
		}

		public function remove(item:Object):Boolean {
			if (nodes.length) {
				return nodes[findIndex(item)].remove(item);
			}
			for (var i:uint=0; i<children.length; i++) {
				if (children[i].key==item.key) {
					children.splice(i,1);
					return true;
				}
			}
			return false;
		}

		protected function findIndex(item:Object):Number {
			var left:Boolean = (item.x > bounds.x + bounds.width / 2) ? false : true;
			var top:Boolean = (item.y > bounds.y + bounds.height / 2) ? false : true;
	
			if (left) {
				if (!top) { return BOTTOM_LEFT; }
			} else {
				if (top) { return TOP_RIGHT; }
				    else { return BOTTOM_RIGHT; }
			}
			return TOP_LEFT;
		}

		protected function subdivide():void {
			var depth:uint=_depth+1;
			var bx:Number = bounds.x;
			var by:Number = bounds.y;

			//floor the values
			var b_w_h:Number = (bounds.width / 2)|0;
			var b_h_h:Number = (bounds.height / 2)|0;
			var bx_b_w_h:Number = bx + b_w_h;
			var by_b_h_h:Number = by + b_h_h;

			nodes[TOP_LEFT    ] = newInstance({ x:bx      , y:by      , width:b_w_h, height:b_h_h }, depth, _maxDepth, _maxChildren);
			nodes[TOP_RIGHT   ] = newInstance({ x:bx_b_w_h, y:by      , width:b_w_h, height:b_h_h }, depth, _maxDepth, _maxChildren);
			nodes[BOTTOM_LEFT ] = newInstance({ x:bx      , y:by_b_h_h, width:b_w_h, height:b_h_h }, depth, _maxDepth, _maxChildren);
			nodes[BOTTOM_RIGHT] = newInstance({ x:bx_b_w_h, y:by_b_h_h, width:b_w_h, height:b_h_h }, depth, _maxDepth, _maxChildren);
		}

		public function clear():void {
			children.length=0;
			for each (var node:Node in nodes) node.clear();
			nodes.length=0;
		}
		
		protected function newInstance(object:Object, depth:uint, maxDepth:uint, maxChildren:Number):Node {
			return new Node(object,depth,maxDepth,maxChildren);
		}
	}
}
