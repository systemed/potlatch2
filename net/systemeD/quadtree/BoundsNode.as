package net.systemeD.quadtree {

	public class BoundsNode extends Node {
		
		/* A list of those children that cross boundaries. (Unfortunately this 
		   means that those that cross the central boundaries are retrieved by
		   everything below: see http://www.mikechambers.com/html5/javascript/QuadTree/examples/retrieve_bounds.html ) */
		private var _stuckChildren:Array=[];

		/* We use this to collect and concatenate items being retrieved. This way
		   we don't have to continuously create new Array instances.
		   Note, when returned from QuadTree.retrieve, we then copy the array. */
		private var _out:Array=[];

		public function BoundsNode(bounds:Object, depth:uint=0, maxDepth:uint=4, maxChildren:Number=4) {
			super(bounds, depth, maxDepth, maxChildren);
		}

		override public function insert(item:Object):void {
			if(nodes.length) {
				var index:Number = findIndex(item);
				var node:Node = nodes[index];

				if (item.x >= node.bounds.x &&
					item.x + item.width <= node.bounds.x + node.bounds.width &&
					item.y >= node.bounds.y &&
					item.y + item.height <= node.bounds.y + node.bounds.height) {
					nodes[index].insert(item);
				} else {			
					_stuckChildren.push(item);
				}
				return;
			}

			children.push(item);
			var len:Number = children.length;
			if(!(_depth>=_maxDepth) && len>_maxChildren) {
				subdivide();
				for (var i:Number=0; i<len; i++) { insert(children[i]); }
				children.length=0;
			}
		}
		
		override public function remove(item:Object):Boolean {
			for (var i:uint=0; i<_stuckChildren.length; i++) {
				if (_stuckChildren[i].key==item.key) {
					_stuckChildren.splice(i,1);
					return true;
				}
			}
			return super(item);
		}
		
		public function getChildren():Array {
			return children.concat(_stuckChildren);
		}
		
		override public function retrieve(item:Object):Array {
			_out.length=0;
			if (nodes.length) {
				_out.push(nodes[findIndex(item)].retrieve(item));
			}
			_out.push(_stuckChildren);
			_out.push(children);
			return _out;
		}
		
		override public function clear():void {
			_stuckChildren.length=0;
			super.clear();
		}

		override protected function newInstance(object:Object, depth:uint, maxDepth:uint, maxChildren:Number):Node {
			return new BoundsNode(object,depth,maxDepth,maxChildren);
		}
	}
}
