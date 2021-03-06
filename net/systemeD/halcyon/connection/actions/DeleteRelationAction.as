package net.systemeD.halcyon.connection.actions {

    import net.systemeD.halcyon.connection.*;
    
    public class DeleteRelationAction extends UndoableEntityAction {
        private var setDeleted:Function;
        private var effects:CompositeUndoableAction;
        private var memberList:Array;
        private var oldMemberList:Array;
        
        public function DeleteRelationAction(relation:Relation, setDeleted:Function, memberList:Array) {
            super(relation, "Delete");
            this.setDeleted = setDeleted;
            this.memberList = memberList;
        }
            
        public override function doAction():uint {
            var relation:Relation = entity as Relation;
            if ( relation.isDeleted() )
                return NO_CHANGE;

            effects = new CompositeUndoableAction("Delete refs");
			relation.removeFromParents(effects.push);
			oldMemberList = memberList.slice();
			for each (var member:RelationMember in memberList) {
			    member.entity.removeParent(relation);
			}
			memberList=[];
			effects.doAction();
			setDeleted(true);
            
            // see note in DeleteNodeAction
            if (relation.id < 0) {
              markClean();
            } else {
              markDirty();
            }
            relation.dispatchEvent(new EntityEvent(Connection.RELATION_DELETED, relation));

            return SUCCESS;
        }
            
        public override function undoAction():uint {
            var relation:Relation = entity as Relation;
            setDeleted(false);
            if (relation.id < 0) {
              markDirty();
            } else {
              markClean();
            }
            relation.dispatchEvent(new EntityEvent(Connection.NEW_RELATION, relation));
            effects.undoAction();
            for each(var member:RelationMember in oldMemberList) {
                memberList.push(member);
                member.entity.addParent(relation);
                relation.dispatchEvent(new RelationMemberEvent(
                        Connection.RELATION_MEMBER_ADDED, member.entity, relation, 0));
            }
            
            return SUCCESS;
        }
    }
}

