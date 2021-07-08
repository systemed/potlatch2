package net.systemeD.halcyon.connection.actions {

    import net.systemeD.halcyon.connection.*;

    /** The action of starting drawing a way. It's a messy action to define because the
    * user deals with nodes rather than ways, and we don't want an undo step that is
    * invisible. Going forwards (redo), the redo of the following node is triggered
    * automatically. Going backwards (undo), the conversion of the last node into a 
    * POI happens automatically. In some ideal universe, both this step and the
    * creation of either the preceding or following node would be bundled together
    * in one CUA, but it turns out to be very hard to implement that way. */
    public class BeginWayAction extends CompositeUndoableAction {

        private var firstNode:Node;
        private var newWay:Way;
        private var connection:Connection;

        public function BeginWayAction(connection:Connection, firstNode: Node){
          super("Begin Way Action");
          this.connection = connection;
          this.firstNode = firstNode;
        }
        
        public override function doAction():uint {
          if (newWay == null) {
            //newWay = connection.createWay({}, [firstNode], push);
            // we create the way, then add the node to it. doing it in one step
            // seemed to cause the undo process to delete the node with the way.
            // A bug in DeleteWayAction.doAction()?
            newWay = connection.createWay({}, [], push);
            newWay.appendNode(firstNode,push);
          } else {
            // This is a redo. Way creation is an invisible step, so we request
            // that the next step (the next node) gets redone as well.
            MainUndoStack.getGlobalStack().requestRedo();
          }

          super.doAction();
          connection.sendEvent(new EntityEvent(Connection.NEW_WAY, newWay), false);
          connection.unregisterPOI(firstNode);
          return SUCCESS;
        }
        
        public override function undoAction():uint {
          super.undoAction();
          connection.registerPOI(firstNode);
          return SUCCESS;
        }
        
        public function getWay():Way {
          return newWay;
        }
        

    }
}