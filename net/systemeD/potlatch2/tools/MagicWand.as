package net.systemeD.potlatch2.tools {
	import net.systemeD.halcyon.connection.*;
	import flash.events.*;
	import flash.net.*;

	/** Tool to add detail to a two-node way from Bing road detection (or, ultimately, GPS). 
		Note: you'll currently need a proxy for the http://magicshop.cloudapp.net/ API until it gets a crossdomain.xml. */

	public class MagicWand {

		private static const DETECT_URL:String="http://127.0.0.1/~richard/cgi-bin/detectroad.cgi";
		private static const MARGIN:Number=0.001;

		/** Add detail to a way.
		 * @param way Way to be modified.
		 * */

		// ** TODO: work on the last two nodes of a way if called from DrawWay
		//			work on individual sections of a way if it has more than one node (and they're more than n metres apart)
		//			work from GPS tracks as well as Bing
		//			magically do junctions
		//			throw an error if way inappropriate
		//			trap IOErrorEvent and HTTPStatusEvent
		//			trap content-free responses

		public static function fromDetection(way:Way, performAction:Function):void {
			if (way.length>2) { return; }
			var wand:MagicWand=new MagicWand(way, performAction);
			wand.requestDetect();
		}
		
		public static function fromGPS(way:Way, performAction:Function):void {
			if (way.length>2) { return; }
			var wand:MagicWand=new MagicWand(way, performAction);
			// ** TODO
		}

		private var way:Way;
		private var connection:Connection;
		private var performAction:Function;
		private var n1:Node, n2:Node;
		private var xmin:Number, xmax:Number, ymin:Number, ymax:Number;

		public function MagicWand(way:Way, performAction:Function):void {
			this.way=way;
			this.connection=way.connection;
			this.performAction=performAction;
			n1=way.getNode(0);
			n2=way.getNode(1);
			xmin=Math.min(n1.lon,n2.lon)-MARGIN;
			xmax=Math.max(n1.lon,n2.lon)+MARGIN;
			ymin=Math.min(n1.lat,n2.lat)-MARGIN;
			ymax=Math.max(n1.lat,n2.lat)+MARGIN;
		}
		
		public function requestDetect():void {
			var qs:String="?pt1="+n1.lat+","+n1.lon+
			              "&pt2="+n2.lat+","+n2.lon+
			              "&bbox="+ymax+","+xmin+","+ymin+","+xmax;
			var loader:URLLoader = new URLLoader();
			loader.addEventListener(Event.COMPLETE, receiveDetect);
			loader.load(new URLRequest(DETECT_URL+qs));
		}
		
		private function receiveDetect(event:Event):void {
            var action:CompositeUndoableAction = new CompositeUndoableAction("Magic Wand");
			var xml:XML=new XML(URLLoader(event.target).data);
			var create:XML=xml.create[0];

			// Read the nodes
			var nodemap:Object={};
			var len:uint=create.node.length();
			var ct:uint=0;
			for each (var n:XML in create.node) {
				ct++; if (ct==1 || ct==len) continue;	// we don't want the first or last nodes, as they duplicate our existing start points
				var node:Node = connection.createNode({}, n.@lat, n.@lon, action.push);
				nodemap[n.@id]=node;
			}

			// Assemble the nodestring
			var w:XML=create.way[0];
			var nodestring:Array=[];
			for each (var nd:XML in w.nd) { nodestring.push(nodemap[nd.@ref]); }

			// Insert into the original way
			for (var i:uint=1; i<=nodestring.length-2; i++) {
				way.insertNode(i,nodestring[nodestring.length-1-i],action.push);
			}
			
			// Do it
			performAction(action);
		}
	}
}
