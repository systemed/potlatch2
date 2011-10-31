package net.systemeD.quadtree {

	/* QuadTree. Based on JavaScript code by Mike Chambers, http://www.mikechambers.com/blog/2011/03/21/javascript-quadtree-implementation/ (MIT-licensed). */

	public class QuadTree {

		private var root:Node;		// root node which covers the entire area being segmented

		/*	Constructor parameters:
			bounds		An object representing the bounds of the top level of the QuadTree. The object 
						should contain the following properties : x, y, width, height
			pointQuad	Whether the QuadTree will contain points (true), or items with bounds (false).
			maxDepth	The maximum number of levels that the quadtree will create. Default is 4.
			maxChildren The maximum number of children that a node can contain before it is split into sub-nodes. */

		public function QuadTree(bounds:Object, pointQuad:Boolean, maxDepth:uint=4, maxChildren:Number=4) {
			var node:Node;
			if (pointQuad) { node = new Node(bounds, 0, maxDepth, maxChildren); }
			else { node = new BoundsNode(bounds, 0, maxDepth, maxChildren); }
			root=node;
		}

		public function insert(item:*):void {
			root.insert(item);
		}

		public function clear():void {
			root.clear();
		}

		/*	Retrieves all items / points in the same node as the specified item / point. If the specified item
			overlaps the bounds of a node, then all children in both nodes will be returned.
			item -	An object representing a 2D coordinate point (with x, y properties), or a shape
					with dimensions (x, y, width, height) properties. */
		public function retrieve(item:Object):Array {
			return root.retrieve(item).slice();
		}
	}
}
