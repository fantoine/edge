package edge.macro;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
using haxe.macro.ComplexTypeTools;
using haxe.macro.TypeTools;
using thx.macro.MacroFields;
using thx.macro.MacroTypes;
using thx.core.Strings;

class BuildSystemProcess {
  public static function createProcessType(systemName : String, processName : String, systemFields : Array<Field>) {
    var pack = processName.split('.'),
        name = pack.pop(),
        system = Context.getType(systemName).toComplexType(),
        fields = [],
        kind = TDClass(
          null,
          [{ pack : ['edge'], name : 'ISystemProcess' }],
          false
        );

    injectConstructor(system, fields);
    injectSystemField(system, fields);
    injectUpdate(systemFields, fields);
    injectSetEntity(systemFields, fields);
    injectFeatureCollections(fields);

    Context.defineType({
      pos : Context.currentPos(),
      params : [],
      pack : pack,
      name : name,
      meta : [],
      kind : kind,
      isExtern : false,
      fields : fields
    });
  }

  static function injectUpdate(systemFields : Array<Field>, fields : Array<Field>) {
    var exprs = [];
    if(BuildSystem.hasVarField(systemFields, "engine"))
      exprs.push(macro system.engine = engine);
    if(BuildSystem.hasVarField(systemFields, "timeDelta"))
      exprs.push(macro system.timeDelta = delta);
    if(BuildSystem.hasFunField(systemFields, "before"))
      exprs.push(macro system.before());

    var update = BuildSystem.findField(systemFields, "update"),
        constructor = BuildSystem.findField(fields, "new");

    if(fieldFunctionHasArguments(update)) {
      var args = fieldFunctionArguments(update),
          fieldTypes = args.map(function(arg) : Field {
              var t = Context.follow(arg.type.toType()).toComplexType(),
                  kind : FieldType = FVar(t, null);
              return {
                pos  : Context.currentPos(),
                name : arg.name,
                //access : null, //[APublic],
                //meta : null,
                kind : kind//,
                //doc : null
              };
            }),
          type = TPath({
              pack : ["edge"],
              name : "View",
              params : [TPType(TAnonymous(fieldTypes))] //[TPType(TAnonymous(fieldTypes))]
            });
//      $type(args);
//      $type(fieldTypes);
      fields.push({
        name : "updateItems",
        kind: FVar(type, null),
        pos: Context.currentPos()
      });
//      trace(args);
      // inject constructor init
      appendExprToFieldFunction(constructor, macro updateItems = new edge.View());
      // create loop expression
      exprs.push(macro var data);
      var expr = '\nfor(item in updateItems) {\n';
      // set entity if required
      if(BuildSystem.hasVarField(systemFields, "entity"))
        expr += '  system.entity = item.entity;\n';
      // call update
      expr += '  data = item.data;\n';
      expr += '  system.update(' + args.map(function(arg) {
          return 'data.${arg.name}';
        }).join(", ") + ');\n';
      expr += '}';
//      trace(expr);
      exprs.push(Context.parse(expr, Context.currentPos()));
    } else {
      exprs.push(macro system.update());
    }

    fields.push({
      name : "update",
      access: [APublic],
      kind: FFun({
        ret : macro : Void,
        params : null,
        expr : macro $b{exprs},
        args : [{
          name : "engine",
          type : macro : edge.Engine
        }, {
          name : "delta",
          type : macro : Float
        }]
      }),
      pos: Context.currentPos()
    });
  }

  static function injectSetEntity(systemFields : Array<Field>, fields : Array<Field>) {
    var exprs = [];
    if(BuildSystem.hasVarField(systemFields, "entity"))
      exprs.push(macro system.entity = entity);

    fields.push({
      name : "setEntity",
      access: [APublic],
      kind: FFun({
        ret : macro : Void,
        params : null,
        expr : macro $b{exprs},
        args : [{
          name : "entity",
          type : macro : edge.Entity
        }]
      }),
      pos: Context.currentPos()
    });
  }

  static function injectSystemField(system : ComplexType, fields : Array<Field>) {
    fields.push({
      name : "system",
      kind: FVar(system, null),
      pos: Context.currentPos()
    });
  }

  static function injectConstructor(system : ComplexType, fields : Array<Field>) {
    fields.push({
      name: "new",
      access: [APublic],
      kind: FFun({
        ret : macro : Void,
        params : null,
        expr : macro this.system = system,
        args : [{
          name : "system",
          type : system
        }]
      }),
      pos: Context.currentPos()
    });
  }

  static function injectFeatureCollections(fields : Array<Field>) {
    // public var collections : Map<String, ViewInfo>;
    injectViewCollection(fields);
  }

  static function injectViewCollection(fields : Array<Field>) {
    var constructor = BuildSystem.findField(fields, "new");

    appendExprToFieldFunction(
      BuildSystem.findField(fields, "new"),
      macro this.collections = new Map()
    );

    fields.push({
      access : [APublic],
      name : "collections",
      kind: FVar(macro : Map<String, edge.ViewInfo>, null),
      pos: Context.currentPos()
    });
  }

  static function appendExprToFieldFunction(field : Field, expr : Expr) {
    switch field.kind {
      case FFun(o):
        var exprs = [o.expr, expr];
        o.expr = macro $b{exprs};
      case _:
    }
  }

  static function fieldFunctionHasArguments(field : Field) {
    switch field.kind {
      case FFun(o):
        return o.args.length > 0;
      case _:
        return false;
    }
  }

  static function fieldFunctionArguments(field : Field) {
    switch field.kind {
      case FFun(o):
        return o.args;
      case _:
        return null;
    }
  }
}