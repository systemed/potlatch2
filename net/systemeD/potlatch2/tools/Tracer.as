package net.systemeD.potlatch2.tools {
	import net.systemeD.halcyon.connection.*;
	import net.systemeD.halcyon.Map;
	import flash.utils.Dictionary;

	/**	Automatically trace vectors from a tiled background.
		Still to do:
		- do something if there are no junctions at all, just one isolated way
		- don't hardcode tolerances
		- pick up coloursets (including 'ignorable' colours for streetnames) from imagery.xml
		- automatically join adjacent ways with a similar bearing
		- show some progress display
		- don't break utterly if you try and trace a non-road thing
		- be zoom-level sensitive (currently works best at OSSV 16)
		- crop to viewport only (optionally?)
		- magically join to existing nodes/ways (using quadtree I guess)
	*/

	public class Tracer {

		private var connection:Connection;
		private var map:Map;
		private var stack:Array=[];		// list of 'open' pixels
		private var pixels:Object={};	// hash of pixels by x,y
		private var xmin:Number=Number.POSITIVE_INFINITY, xmax:Number=Number.NEGATIVE_INFINITY;
		private var ymin:Number=Number.POSITIVE_INFINITY, ymax:Number=Number.NEGATIVE_INFINITY;

		private static var neighbourhoods:Array=[
			0,0,0,1,0,0,1,3,0,0,3,1,1,0,1,3,0,0,0,0,0,0,0,0,2,0,2,0,3,0,3,3,
			0,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,3,0,2,2,
			0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
			2,0,0,0,0,0,0,0,2,0,0,0,2,0,0,0,3,0,0,0,0,0,0,0,3,0,0,0,3,0,2,0,
			0,0,3,1,0,0,1,3,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
			3,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
			2,3,1,3,0,0,1,3,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
			2,3,0,1,0,0,0,1,0,0,0,0,0,0,0,0,3,3,0,1,0,0,0,0,2,2,0,0,2,0,0,0];

		public function Tracer(startX:Number,startY:Number,map:Map):void {
			this.map=map;
			connection=map.editableLayer.connection;

			var px:Number=map.tileset.lon2pixel(map.coord2lon(startX));
			var py:Number=map.tileset.lat2pixel(map.coord2lat(startY));
			createPixelIndex(px,py);
			
			// make lines into skeletons
			var pass:uint=0, removed:uint;
			do {
				removed=thin(pass);
				pass++;
			} while (removed>0);

			// mark the junctions
			stack=[];
			for (var x:Number=xmin; x<=xmax; x++) {
				for (var y:Number=ymin; y<=ymax; y++) {
					if (!pixelExists(x,y)) continue;
					if (connections(x,y).length>2) { pixels[x][y].junction=true; stack.push(pixels[x][y]); }
				}
			}

			// slim junctions so we don't have two next to each other unnecessarily
			do { removed=thinJunctions(); } while (removed>0);
			
			// create pixel chains
			stack=[];
			for (x=xmin; x<=xmax; x++) {
				for (y=ymin; y<=ymax; y++) {
					if (pixelExists(x,y) && pixels[x][y].junction) { stack.push(pixels[x][y]); }
				}
			}
			createPixelChains();
		}
		
		/* Flood-fill from the clicked point, and store the results in pixels[][] */
		
		private function createPixelIndex(startX:Number,startY:Number):void {
			var rgb:int=map.tileset.pixelAt(startX,startY); if (!rgb) return;
			stack=[new TracerPoint(startX,startY,false,rgb)];
			addToPixels(stack[0]);

			while (stack.length>0) {
				var p:TracerPoint=stack.shift();
				newFromOffset(p,-1,-1); newFromOffset(p,-1, 0); newFromOffset(p,-1, 1);
				newFromOffset(p, 0,-1);                         newFromOffset(p, 0, 1);
				newFromOffset(p, 1,-1); newFromOffset(p, 1, 0); newFromOffset(p, 1, 1);
			}
		}

		private function addToPixels(p:TracerPoint):void {
			if (!pixels[p.x]) { pixels[p.x]={}; }
			pixels[p.x][p.y]=p;
			xmin=Math.min(p.x,xmin); xmax=Math.max(p.x,xmax);
			ymin=Math.min(p.y,ymin); ymax=Math.max(p.y,ymax);
		}
		private function deletePixel(p:TracerPoint):void {
			delete pixels[p.x][p.y];
// map.tileset.setPixel(p.x,p.y,0xFFFFFF);
			p=null;
		}
		private function pixelExists(x:Number,y:Number):Boolean {
			if (!pixels[x]) return false;
			if (!pixels[x][y]) return false;
			return true;
		}
		
		private function getFromOffset(p:TracerPoint,xo:int,yo:int):TracerPoint {
			return pixelExists(p.x+xo,p.y+yo) ? pixels[p.x+xo][p.y+yo] : null;
		}

		private function newFromOffset(p:TracerPoint,xo:int,yo:int):void {
			var newp:TracerPoint;
			var newx:Number=p.x+xo;
			var newy:Number=p.y+yo;
			if (pixelExists(newx,newy)) return;
			var rgb:int=map.tileset.pixelAt(newx,newy); if (!rgb) return;

			var lab:Object=TracerPoint.lab(rgb);
			var diff:Number=p.difference(lab.l,lab.a,lab.b);
			if (diff<15) {
				newp=new TracerPoint(newx,newy,false,lab.l,lab.a,lab.b);
				stack.push(newp); addToPixels(newp);
// map.tileset.setPixel(newx,newy,0);
			} else {
				newp=new TracerPoint(newx,newy,true,lab.l,lab.a,lab.b);
				addToPixels(newp);
// map.tileset.setPixel(newx,newy,0xFF0000);
			}
		}

		/* Thin the filled image to a simple skeleton.
		   Code adapted from ImageJ (public domain - thanks!)
		   http://rsbweb.nih.gov/ij/developer/source/ij/process/BinaryProcessor.java.html */

		private function thin(pass:int):uint {
			var removed:uint=0;
			var toRemove:Array=[];
			for (var x:Number=xmin; x<=xmax; x++) {
				for (var y:Number=ymin; y<=ymax; y++) {
					if (!pixelExists(x,y)) continue;
					var p:TracerPoint=pixels[x][y];

					var index:uint=0;
					if (testFromOffset(p,-1,-1)) { index+=1; }		// p1
					if (testFromOffset(p, 0,-1)) { index+=2; }		// p2
					if (testFromOffset(p, 1,-1)) { index+=4; }		// p3
					if (testFromOffset(p, 1, 0)) { index+=8; }		// p6
					if (testFromOffset(p, 1, 1)) { index+=16; }		// p9
					if (testFromOffset(p, 0, 1)) { index+=32; }		// p8
					if (testFromOffset(p,-1, 1)) { index+=64; }		// p7
					if (testFromOffset(p,-1, 0)) { index+=128;}		// p4

					var code:uint=neighbourhoods[index];
					if ((pass & 1)==1) {		// odd pass
						if (code==2 || code==3) { toRemove.push(p); removed++; }
					} else {					// even pass
						if (code==1 || code==3) { toRemove.push(p); removed++; }
					}
				}
			}
			for each (p in toRemove) { deletePixel(p); }
			return removed;
		}

		private function testFromOffset(p:TracerPoint,xo:int,yo:int):Boolean {
			return pixelExists(p.x+xo,p.y+yo);
		}
		
		/* Thin out junction nodes so we don't have more than one next to each other */
		
		private function thinJunctions():uint {
			var removed:uint=0;
			for (var x:Number=xmin; x<=xmax; x++) {
				for (var y:Number=ymin; y<=ymax; y++) {
					if (!pixelExists(x,y)) continue;
					if (!pixels[x][y].junction) continue;

					// Find how many adjoining pixels are junctions, and how many aren't
					var conns:Array=connections(x,y);
					var junctions:uint=0; var points:uint=0;
					for each (var p:TracerPoint in conns) {
						if (p.junction) { junctions++ } else { points++ }
					}

					// If there's only one non-junction, but several junctions, we don't need this
					if (points<2 && junctions>0) {
						pixels[x][y].junction=false;
						removed++;

					// If every adjacent junction is _directly_ next to a non-junction (i.e. non-diagonal),
					// then we can use the adjacent junction, so we don't need this
					} else if (junctions>0) {
						p=pixels[x][y];
						// (array looping around - we double up first and last entries)
						var around:Array=[getFromOffset(p,-1,0),
						                  getFromOffset(p,-1,1), getFromOffset(p,0, 1), getFromOffset(p, 1, 1), getFromOffset(p, 1,0),
						                  getFromOffset(p,1,-1), getFromOffset(p,0,-1), getFromOffset(p,-1,-1), getFromOffset(p,-1,0),
						                  getFromOffset(p,-1,1)];
						var removable:Boolean=true;
						for (var i:uint=1; i<=8; i++) {
							if (around[i] && around[i].junction && !around[i-1] && !around[i+1]) {
								removable=false;
							}
						}
						if (removable) { pixels[x][y].junction=false; removed++; }
					}
				}
			}
			return removed;
		}

		/* Create pixel chains of each 'way' 
		   On entry, stack contains a list of junction pixels.
		   Essentially this is a very simple routing engine:
			- start from a junction node
			- create a stack of destination nodes, each with a parent, and a distance (add 1 for horizontal, 1.4 for diagonal)
			- traverse all children _but_ stop when they get to a junction node or a dead-end node
			- finish traversing when everything explored
			
		   Then delete dupes and short dead-ends, and simplify with Douglas-Peucker.
		   Finally, convert into OSM nodes/ways. */
		
		private function createPixelChains():void {
			var r:TracerPoint;
			var ways:Array=[];
			while (stack.length>0) {
				var start:TracerPoint=stack.shift();
				var pixelStack:Array=[start];				// stack of nodes currently being explored
				var termini:Array=[];						// the destinations we've reached
				var distances:Array=[]; setMD(distances,start,0);
				var parents:Object={};

				while (pixelStack.length>0) {
					var p:TracerPoint=pixelStack.shift();
					var conns:Array=connections(p.x,p.y);

					// if there are junctions adjacent, we want to 'home in' on them
					var junctionsonly:Boolean=false;
					for each (r in conns) {
						if (r.junction && !(r.x==start.x && r.y==start.y)) junctionsonly=true;
					}
					
					for each (r in conns) {
						if (junctionsonly && !r.junction) continue;

						var xo:int=r.x-p.x; var yo:int=r.y-p.y;
						var newdist:Number=getMDNumeric(distances,p)+((Math.abs(xo)+Math.abs(yo)==2) ? 1.4 : 1);
						var addToStack:Boolean=false;

						// if we haven't been there yet, add it
						var olddist:Number=getMDNumeric(distances,r);
						if (isNaN(olddist)) {
							setMD(distances,r,newdist);
							setMD(parents  ,r,p);
							addToStack=true;

						// if we have been there and this is quicker, add it
						} else if (newdist<olddist) {
							setMD(distances,r,newdist);
							setMD(parents  ,r,p);
							addToStack=true;
						}

						// if it's a terminus or a dead-end, stop looking
						if (r.junction || connections(r.x,r.y).length<2) {
							if (termini.indexOf(r)<0) { 
								termini.push(r);
							}

						// unless it's a terminus/dead-end, add it to the stack
						} else if (addToStack) {
							if (pixelStack.indexOf(r)<0) pixelStack.push(r);
						}
					}
				}

				// Add to way list
				for each (p in termini) {
					var way:Array=[];
					r=p;
					do { way.push(r); r=getMD(parents,r); } while(r);
					if (way.length<4) continue;
					if (way[0].x>way[way.length-1].x) way.reverse();
					ways.push(way);
				}
			}
			
			// Delete duplicate ways
			var way2:Array, longer:Array, shorter:Array, keep:Object={};
			for each (way in ways) {
				if (way.length==0) continue;
				for each (way2 in ways) {
					if (way2.length==0 || way.length==0) continue;
					if (way2==way) continue;
					if (way2.length>way.length) { longer=way2; shorter=way; }
					                       else { shorter=way2; longer=way; }
					if (dupePath(shorter,longer)) { shorter.length=0; }
				}
			}
			
			// Douglas-Peuckerise each one (chopping dead-ends of <n length)
			var finalways:Array=[];
			var xa:Number, xb:Number;
			var ya:Number, yb:Number;
			var l:Number, d:Number, i:uint;
			var tolerance:Number=3;
			var furthest:uint, furthdist:Number, float:uint;
			for each (way in ways) {
				if (way.length==0) continue;
				if (way.length<10 && isDeadEnd(way)) { way=[]; continue; }
				var tokeep:Array=[];
				stack=[way.length-1];
				var anchor:uint=0;
		
				// Douglas-Peucker
				while (stack.length) {
					float=stack[stack.length-1];
					furthest=0; furthdist=0;
					xa=way[anchor].x; xb=way[float].x;
					ya=way[anchor].y; yb=way[float].y;
					l=Math.sqrt((xb-xa)*(xb-xa)+(yb-ya)*(yb-ya));
	
					// find furthest-out point
					for (i=anchor+1; i<float; i+=1) {
						d=Simplify.getDistance(xa,ya, xb,yb, l, way[i].x,way[i].y);
						if (d>furthdist && d>tolerance) { furthest=i; furthdist=d; }
					}
			
					if (furthest==0) {
						anchor=stack.pop();
						tokeep[float]=true;
					} else {
						stack.push(furthest);
					}
				}
			
				// Delete unwanted nodes
				var newway:Array=[way[0]];
				for (i=1; i<way.length; i++) {
					if (tokeep[i]) newway.push(way[i]);
				}
				finalways.push(newway);
			}
			
			// Create nodes and ways (reusing the same node for start/end points within a certain radius)
			var action:CompositeUndoableAction = new CompositeUndoableAction("trace");
			var nodemap:Array=[];
			for each (way in finalways) {
				var nodestring:Array=[];
				for (i=0; i<way.length; i++) {
					var node:Node=getMD(nodemap,way[i]);
					if (!node) {
						node=connection.createNode({}, 
						                           map.tileset.pixel2lat(way[i].y), 
						                           map.tileset.pixel2lon(way[i].x), action.push);
						setMD(nodemap,way[i],node);
					}
					nodestring.push(node);
				}
                connection.createWay({}, nodestring, action.push);
			}
			MainUndoStack.getGlobalStack().addAction(action);
		}

		/* Compare two ways to see if one duplicates the other */
		
		private function dupePath(way1:Array,way2:Array):Boolean {
			var dx:uint,dy:uint;
			dx=Math.abs(way1[0].x-way2[0].x);
			dy=Math.abs(way1[0].y-way2[0].y);
			if (dx>2 || dy>2) return false;
			dx=Math.abs(way1[way1.length-1].x-way2[way2.length-1].x);
			dy=Math.abs(way1[way1.length-1].y-way2[way2.length-1].y);
			if (dx>2 || dy>2) return false;
			return true;
		}
		
		/* Check whether a way is a dead end */
		
		private function isDeadEnd(way:Array):Boolean {
			if (connections(way[0           ].x,way[0           ].y).length==1) return true;
			if (connections(way[way.length-1].x,way[way.length-1].y).length==1) return true;
			return false;
		}

		/* Convenience functions for multi-dimensional arrays */

		private function setMD(obj:Object,r:TracerPoint,o:*):void {
			if (!obj[r.x]) obj[r.x]={};
			obj[r.x][r.y]=o;
		}
		private function getMD(obj:Object,r:TracerPoint):* {
			if (!obj[r.x]) return null;
			return obj[r.x][r.y];
		}
		private function getMDNumeric(obj:Object,r:TracerPoint):Number {
			if (!obj[r.x]) return NaN;
			return obj[r.x][r.y];
		}
		
		/* Find all adjoining ('connecting') pixels */

		private function connections(x:Number,y:Number):Array {
			if (!pixelExists(x,y)) return [];
			var connections:Array=[];
			for (var xi:int=-1; xi<=1; xi++) {
				for (var yi:int=-1; yi<=1; yi++) {
					if (xi==0 && yi==0) continue;
					if (pixelExists(x+xi,y+yi)) connections.push(pixels[x+xi][y+yi]);
				}
			}
			return connections;
		}
	}
}
