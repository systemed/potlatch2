package net.systemeD.halcyon.connection.actions {

    import net.systemeD.halcyon.connection.*;

    /* This is needed so that the specific type of CUA can be detected when CreatePOIAction is called */
    public class BeginWayAction extends CompositeUndoableAction {

        private var newNode:Node;
        private var newWay:Way;
        private var lat:Number;
        private var lon:Number;
        private var connection:Connection;

        public function BeginWayAction(connection:Connection, lat:Number, lon:Number){
          super("Begin Way Action");
          this.connection = connection;
          this.lat = lat;
          this.lon = lon;
        }
        
        public override function doAction():uint {
          if (newNode == null) {
            newNode = connection.createNode({}, lat, lon, push);
            newWay = connection.createWay({}, [newNode], push);
          }
          super.doAction();
          
          return SUCCESS;
        }
        
        public override function undoAction():uint {
          super.undoAction();
          // this is needed because AddNodeToWayAction turns the first node into a POI when undoing. Hrm...
          connection.unregisterPOI(newNode);
          
          return SUCCESS;
        }
        
        public function getNode():Node {
          return newNode;
        }
        public function getWay():Way {
          return newWay;
        }
        
        public function getNodeCreation():CreateEntityAction {
        	return this.getActions()[0];
        }


    }
}