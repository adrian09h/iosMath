//
//  MathAtomFactory.m
//  iosMath
//
//  Created by Kostub Deshmukh on 8/28/13.
//  Copyright (C) 2013 MathChat
//   
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

#import "MTMathAtomFactory.h"
#import "MTMathListBuilder.h"

NSString *const MTSymbolMultiplication = @"\u00D7";
NSString *const MTSymbolDivision = @"\u00F7";
NSString *const MTSymbolFractionSlash = @"\u2044";
NSString *const MTSymbolWhiteSquare = @"\u25A1";
NSString *const MTSymbolBlackSquare = @"\u25A0";
NSString *const MTSymbolLessEqual = @"\u2264";
NSString *const MTSymbolGreaterEqual = @"\u2265";
NSString *const MTSymbolNotEqual = @"\u2260";
NSString *const MTSymbolSquareRoot = @"\u221A"; // \sqrt
NSString *const MTSymbolCubeRoot = @"\u221B";
NSString *const MTSymbolInfinity = @"\u221E"; // \infty
NSString *const MTSymbolAngle = @"\u2220"; // \angle
NSString *const MTSymbolDegree = @"\u00B0"; // \circ

@implementation MTMathAtomFactory

+ (MTMathAtom *)times
{
    return [MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:MTSymbolMultiplication];
}

+ (MTMathAtom *)divide
{
    return [MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:MTSymbolDivision];
}

+ (MTMathAtom *)placeholder
{
    return [MTMathAtom atomWithType:kMTMathAtomPlaceholder value:MTSymbolWhiteSquare];
}

+ (MTFraction *)placeholderFraction
{
    MTFraction *frac = [MTFraction new];
    frac.numerator = [MTMathList new];
    [frac.numerator addAtom:[self placeholder]];
    frac.denominator = [MTMathList new];
    [frac.denominator addAtom:[self placeholder]];
    return frac;
}

+ (MTRadical*) placeholderRadical
{
    MTRadical* rad = [MTRadical new];
    rad.degree = [MTMathList new];
    rad.radicand = [MTMathList new];
    [rad.degree addAtom:self.placeholder];
    [rad.radicand addAtom:self.placeholder];
    return rad;
}

+ (MTMathAtom *)placeholderSquareRoot
{
    MTRadical *rad = [MTRadical new];
    rad.radicand = [MTMathList new];
    [rad.radicand addAtom:[self placeholder]];
    return rad;
}

+ (MTLargeOperator *)operatorWithName:(NSString *)name limits:(bool) limits
{
    return [[MTLargeOperator alloc] initWithValue:name limits:limits];
}

+ (nullable MTMathAtom *)atomForCharacter:(unichar)ch
{
    NSString *chStr = [NSString stringWithCharacters:&ch length:1];
    if (ch > 0x0410 && ch < 0x044F){
        // show basic cyrillic alphabet. Latin Modern Math font is not good for cyrillic symbols
        return [MTMathAtom atomWithType:kMTMathAtomOrdinary value:chStr];
    } else if (ch < 0x21 || ch > 0x7E) {
        // skip non ascii characters and spaces
        return nil;
    } else if (ch == '$' || ch == '%' || ch == '#' || ch == '&' || ch == '~' || ch == '\'') {
        // These are latex control characters that have special meanings. We don't support them.
        return nil;
    } else if (ch == '^' || ch == '_' || ch == '{' || ch == '}' || ch == '\\') {
        // more special characters for Latex.
        return nil;
    } else if (ch == '(' || ch == '[') {
        return [MTMathAtom atomWithType:kMTMathAtomOpen value:chStr];
    } else if (ch == ')' || ch == ']' || ch == '!' || ch == '?') {
        return [MTMathAtom atomWithType:kMTMathAtomClose value:chStr];
    } else if (ch == ',' || ch == ';') {
        return [MTMathAtom atomWithType:kMTMathAtomPunctuation value:chStr];
    } else if (ch == '=' || ch == '>' || ch == '<') {
        return [MTMathAtom atomWithType:kMTMathAtomRelation value:chStr];
    } else if (ch == ':') {
        // Math colon is ratio. Regular colon is \colon
        return [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2236"];
    } else if (ch == '-') {
        // Use the math minus sign
        return [MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2212"];
    } else if (ch == '+' || ch == '*') {
        return [MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:chStr];
    } else if (ch == '.' || (ch >= '0' && ch <= '9')) {
        return [MTMathAtom atomWithType:kMTMathAtomNumber value:chStr];
    } else if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
        return [MTMathAtom atomWithType:kMTMathAtomVariable value:chStr];
    } else if (ch == '"' || ch == '/' || ch == '@' || ch == '`' || ch == '|') {
        // just an ordinary character. The following are allowed ordinary chars
        // | / ` @ "
        return [MTMathAtom atomWithType:kMTMathAtomOrdinary value:chStr];
    } else {
        NSAssert(false, @"Unknown ascii character %@. Should have been accounted for.", @(ch));
        return nil;
    }
}

+ (MTMathList *)mathListForCharacters:(NSString *)chars
{
    NSParameterAssert(chars);
    NSInteger len = chars.length;
    unichar buff[len];
    [chars getCharacters:buff range:NSMakeRange(0, len)];
    MTMathList* list = [[MTMathList alloc] init];
    for (NSInteger i = 0; i < len; i++) {
        MTMathAtom* atom = [self atomForCharacter:buff[i]];
        if (atom) {
            [list addAtom:atom];
        }
    }
    return list;
}

+ (nullable MTMathAtom *)atomForLatexSymbolName:(NSString *)symbolName
{
    NSParameterAssert(symbolName);
    NSDictionary* aliases = [MTMathAtomFactory aliases];
    // First check if this is an alias
    NSString* canonicalName = aliases[symbolName];
    if (canonicalName) {
        // Switch to the canonical name
        symbolName = canonicalName;
    }
    
    NSDictionary* commands = [self supportedLatexSymbols];
    MTMathAtom* atom = commands[symbolName];
    if (atom) {
        // Return a copy of the atom since atoms are mutable.
        return [atom copy];
    }
    return nil;
}

+ (nullable NSString*) latexSymbolNameForAtom:(MTMathAtom*) atom
{
    if (atom.nucleus.length == 0) {
        return nil;
    }
    NSDictionary* dict = [MTMathAtomFactory textToLatexSymbolNames];
    return dict[atom.nucleus];
}

+ (void)addLatexSymbol:(NSString *)name value:(MTMathAtom *)atom
{
    NSParameterAssert(name);
    NSParameterAssert(atom);
    NSMutableDictionary<NSString*, MTMathAtom*>* commands = [self supportedLatexSymbols];
    commands[name] = atom;
    if (atom.nucleus.length != 0) {
        NSMutableDictionary<NSString*, NSString*>* dict = [self textToLatexSymbolNames];
        dict[atom.nucleus] = name;
    }
}

+ (NSArray<NSString *> *)supportedLatexSymbolNames
{
    NSDictionary<NSString*, MTMathAtom*>* commands = [MTMathAtomFactory supportedLatexSymbols];
    return commands.allKeys;
}

+ (nullable MTAccent*) accentWithName:(NSString*) accentName
{
    NSDictionary<NSString*, NSString*> *accents = [MTMathAtomFactory accents];
    NSString* accentValue = accents[accentName];
    if (accentValue) {
        return [[MTAccent alloc] initWithValue:accentValue];
    } else {
        return nil;
    }
}

+(NSString*) accentName:(MTAccent*) accent
{
    NSDictionary* dict = [MTMathAtomFactory accentValueToName];
    return dict[accent.nucleus];
}

+ (nullable MTMathAtom *)boundaryAtomForDelimiterName:(NSString *)delimName
{
    NSDictionary<NSString*, NSString*>* delims = [MTMathAtomFactory delimiters];
    NSString* delimValue = delims[delimName];
    if (!delimValue) {
        return nil;
    }
    return [MTMathAtom atomWithType:kMTMathAtomBoundary value:delimValue];
}

+ (NSString*) delimiterNameForBoundaryAtom:(MTMathAtom*) boundary
{
    if (boundary.type != kMTMathAtomBoundary) {
        return nil;
    }
    NSDictionary* dict = [self delimValueToName];
    return dict[boundary.nucleus];
}

+ (MTFontStyle)fontStyleWithName:(NSString *)fontName {
    NSDictionary<NSString*, NSNumber*>* fontStyles = [self fontStyles];
    NSNumber* style = fontStyles[fontName];
    if (style == nil) {
        return NSNotFound;
    }
    return style.integerValue;
}

+ (NSString *)fontNameForStyle:(MTFontStyle)fontStyle
{
    switch (fontStyle) {
        case kMTFontStyleDefault:
            return @"mathnormal";

        case kMTFontStyleRoman:
            return @"mathrm";

        case kMTFontStyleBold:
            return @"mathbf";

        case kMTFontStyleFraktur:
            return @"mathfrak";

        case kMTFontStyleCaligraphic:
            return @"mathcal";

        case kMTFontStyleItalic:
            return @"mathit";

        case kMTFontStyleSansSerif:
            return @"mathsf";

        case kMTFontStyleBlackboard:
            return @"mathbb";

        case kMTFontStyleTypewriter:
            return @"mathtt";

        case kMTFontStyleBoldItalic:
            return @"bm";
    }
}

+ (MTFraction *)fractionWithNumerator:(MTMathList *)num denominator:(MTMathList *)denom
{
    MTFraction *frac = [[MTFraction alloc] init];
    frac.numerator = num;
    frac.denominator = denom;
    return frac;
}

+ (MTFraction *)fractionWithNumeratorStr:(NSString *)numStr denominatorStr:(NSString *)denomStr
{
    MTMathList* num = [self mathListForCharacters:numStr];
    MTMathList* denom = [self mathListForCharacters:denomStr];
    return [self fractionWithNumerator:num denominator:denom];
}

+ (nullable MTMathAtom *)tableWithEnvironment:(NSString *)env rows:(NSArray<NSArray<MTMathList *> *> *)rows error:(NSError * _Nullable __autoreleasing *)error
{
    MTMathTable* table = [[MTMathTable alloc] initWithEnvironment:env];
    for (int i = 0; i < rows.count; i++) {
        NSArray<MTMathList*>* row = rows[i];
        for (int j = 0; j < row.count; j++) {
            [table setCell:row[j] forRow:i column:j];
        }
    }
    static NSDictionary<NSString*, NSArray*>* matrixEnvs = nil;
    if (!matrixEnvs) {
        matrixEnvs = @{ @"matrix" : @[],
                        @"pmatrix" : @[ @"(", @")"],
                        @"bmatrix" : @[ @"[", @"]"],
                        @"Bmatrix" : @[ @"{", @"}"],
                        @"vmatrix" : @[ @"vert", @"vert"],
                        @"Vmatrix" : @[ @"Vert", @"Vert"], };
    }
    if ([matrixEnvs objectForKey:env]) {
        // it is set to matrix as the delimiters are converted to latex outside the table.
        table.environment = @"matrix";
        table.interRowAdditionalSpacing = 0;
        table.interColumnSpacing = 18;
        // All the lists are in textstyle
        MTMathAtom* style = [[MTMathStyle alloc] initWithStyle:kMTLineStyleText];
        for (int i = 0; i < table.cells.count; i++) {
            NSArray<MTMathList*>* row = table.cells[i];
            for (int j = 0; j < row.count; j++) {
                [row[j] insertAtom:style atIndex:0];
            }
        }
        // Add delimiters
        NSArray* delims = [matrixEnvs objectForKey:env];
        if (delims.count == 2) {
            MTInner* inner = [[MTInner alloc] init];
            inner.leftBoundary = [self boundaryAtomForDelimiterName:delims[0]];
            inner.rightBoundary = [self boundaryAtomForDelimiterName:delims[1]];
            inner.innerList = [MTMathList mathListWithAtoms:table, nil];
            return inner;
        } else {
            return table;
        }
    } else if (!env) {
        // The default env.
        table.interRowAdditionalSpacing = 1;
        table.interColumnSpacing = 0;
        NSInteger cols = table.numColumns;
        for (int i = 0; i < cols; i++) {
            [table setAlignment:kMTColumnAlignmentLeft forColumn:i];
        }
        return table;
    } else if ([env isEqualToString:@"eqalign"] || [env isEqualToString:@"split"] || [env isEqualToString:@"aligned"]) {
        if (table.numColumns != 2) {
            NSString* message = [NSString stringWithFormat:@"%@ environment can only have 2 columns", env];
            if (error != nil) {
                *error = [NSError errorWithDomain:MTParseError code:MTParseErrorInvalidNumColumns userInfo:@{ NSLocalizedDescriptionKey : message }];
            }
            return nil;
        }
        // Add a spacer before each of the second column elements. This is to create the correct spacing for = and other releations.
        MTMathAtom* spacer = [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@""];
        for (int i = 0; i < table.cells.count; i++) {
            NSArray<MTMathList*>* row = table.cells[i];
            if (row.count > 1) {
                [row[1] insertAtom:spacer atIndex:0];
            }
        }
        table.interRowAdditionalSpacing = 1;
        table.interColumnSpacing = 0;
        [table setAlignment:kMTColumnAlignmentRight forColumn:0];
        [table setAlignment:kMTColumnAlignmentLeft forColumn:1];
        return table;
    } else if ([env isEqualToString:@"displaylines"] || [env isEqualToString:@"gather"]) {
        if (table.numColumns != 1) {
            NSString* message = [NSString stringWithFormat:@"%@ environment can only have 1 column", env];
            if (error != nil) {
                *error = [NSError errorWithDomain:MTParseError code:MTParseErrorInvalidNumColumns userInfo:@{ NSLocalizedDescriptionKey : message }];
            }
            return nil;
        }
        table.interRowAdditionalSpacing = 1;
        table.interColumnSpacing = 0;
        [table setAlignment:kMTColumnAlignmentCenter forColumn:0];
        return table;
    } else if ([env isEqualToString:@"eqnarray"]) {
        if (table.numColumns != 3) {
            NSString* message = @"eqnarray environment can only have 3 columns";
            if (error != nil) {
                *error = [NSError errorWithDomain:MTParseError code:MTParseErrorInvalidNumColumns userInfo:@{ NSLocalizedDescriptionKey : message }];
            }
            return nil;
        }
        table.interRowAdditionalSpacing = 1;
        table.interColumnSpacing = 18;
        [table setAlignment:kMTColumnAlignmentRight forColumn:0];
        [table setAlignment:kMTColumnAlignmentCenter forColumn:1];
        [table setAlignment:kMTColumnAlignmentLeft forColumn:2];
        return table;
    } else if ([env isEqualToString:@"cases"]) {
        if (table.numColumns != 2) {
            NSString* message = @"cases environment can only have 2 columns";
            if (error != nil) {
                *error = [NSError errorWithDomain:MTParseError code:MTParseErrorInvalidNumColumns userInfo:@{ NSLocalizedDescriptionKey : message }];
            }
            return nil;
        }
        table.interRowAdditionalSpacing = 0;
        table.interColumnSpacing = 18;
        [table setAlignment:kMTColumnAlignmentLeft forColumn:0];
        [table setAlignment:kMTColumnAlignmentLeft forColumn:1];
        // All the lists are in textstyle
        MTMathAtom* style = [[MTMathStyle alloc] initWithStyle:kMTLineStyleText];
        for (int i = 0; i < table.cells.count; i++) {
            NSArray<MTMathList*>* row = table.cells[i];
            for (int j = 0; j < row.count; j++) {
                [row[j] insertAtom:style atIndex:0];
            }
        }
        // Add delimiters
        MTInner* inner = [[MTInner alloc] init];
        inner.leftBoundary = [self boundaryAtomForDelimiterName:@"{"];
        inner.rightBoundary = [self boundaryAtomForDelimiterName:@"."];
        MTMathAtom* space = [self atomForLatexSymbolName:@","];
        inner.innerList = [MTMathList mathListWithAtoms:space, table, nil];
        return inner;
    }
    if (error) {
        NSString* message = [NSString stringWithFormat:@"Unknown environment: %@", env];
        *error = [NSError errorWithDomain:MTParseError code:MTParseErrorInvalidEnv userInfo:@{ NSLocalizedDescriptionKey : message }];
    }
    return nil;
}

+ (NSMutableDictionary<NSString*, MTMathAtom*>*) supportedLatexSymbols
{
    static NSMutableDictionary<NSString*, MTMathAtom*>* commands = nil;
    if (!commands) {
        commands = [NSMutableDictionary dictionaryWithDictionary:@{
                     @"square" : [MTMathAtomFactory placeholder],
                     @"Box" : [MTMathAtomFactory placeholder],
                     
                     // Greek characters
                     @"Alpha"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u0391"],
                     @"Beta"        : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u0392"],
                     @"Bbbk"        : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\U0001d55c"],
                     @"Delta"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u0394"],
                     @"Gamma"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u0393"],
                     @"Im"          : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u2111"],
                     @"Lambda"      : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u039b"],
                     @"Omega"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03a9"],
                     @"Phi"         : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03a6"],
                     @"Pi"          : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03a0"],
                     @"Psi"         : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03a8"],
                     @"Re"          : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u211c"],
                     @"Sigma"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03a3"],
                     @"Theta"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u0398"],
                     @"Upsilon"     : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03a5"],
                     @"Xi"          : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u039e"],
                     @"aleph"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u2135"],
                     @"alpha"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03b1"],
                     @"beta"        : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03b2"],
                     @"beth"        : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u2136"],
                     @"chi"         : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03c7"],
                     @"daleth"      : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u2138"],
                     @"delta"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03b4"],
                     @"digamma"     : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03dc"],
                     @"ell"         : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u2113"],
                     @"epsilon"     : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03f5"],
                     @"eta"         : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03b7"],
                     @"eth"         : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u00f0"],
                     @"gamma"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03b3"],
                     @"gimel"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u2137"],
                     @"hbar"        : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u210f"],
                     @"hslash"      : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u210f"],
                     @"imath"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u0131"],
                     @"iota"        : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03b9"],
                     @"jmath"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u0237"],
                     @"kappa"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03ba"],
                     @"lambda"      : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03bb"],
                     @"mu"          : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03bc"],
                     @"nu"          : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03bd"],
                     @"omega"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03c9"],
                     @"phi"         : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03d5"],
                     @"pi"          : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03c0"],
                     @"psi"         : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03c8"],
                     @"rho"         : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03c1"],
                     @"sigma"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03c3"],
                     @"tau"         : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03c4"],
                     @"theta"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03b8"],
                     @"upsilon"     : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03c5"],
                     @"varDelta"    : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\U0001d6e5"],
                     @"varGamma"    : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\U0001d6e4"],
                     @"varLambda"   : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\U0001d6ec"],
                     @"varOmega"    : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\U0001d6fa"],
                     @"varPhi"      : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\U0001d6f7"],
                     @"varPi"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\U0001d6f1"],
                     @"varPsi"      : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\U0001d6f9"],
                     @"varSigma"    : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\U0001d6f4"],
                     @"varTheta"    : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\U0001d6e9"],
                     @"varUpsilon"  : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\U0001d6f6"],
                     @"varXi"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\U0001d6ef"],
                     @"varepsilon"  : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03b5"],
                     @"varkappa"    : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\U0001d718"],
                     @"varphi"      : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03c6"],
                     @"varpi"       : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03d6"],
                     @"varrho"      : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03f1"],
                     @"varsigma"    : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03c2"],
                     @"vartheta"    : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03d1"],
                     @"wp"          : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u2118"],
                     @"xi"          : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03be"],
                     @"zeta"        : [MTMathAtom atomWithType:kMTMathAtomVariable value:@"\u03b6"],
                     
                     // Open
                     @"Lbag"    : [MTMathAtom atomWithType:kMTMathAtomOpen value:@"\u27c5"],
                     @"langle"  :[MTMathAtom atomWithType:kMTMathAtomOpen value:@"\u27e8"],
                     @"lbag"    :[MTMathAtom atomWithType:kMTMathAtomOpen value:@"\u27c5"],
                     @"lceil"   :[MTMathAtom atomWithType:kMTMathAtomOpen value:@"\u2308"],
                     @"lfloor"  :[MTMathAtom atomWithType:kMTMathAtomOpen value:@"\u230a"],
                     @"lgroup"  :[MTMathAtom atomWithType:kMTMathAtomOpen value:@"\u27ee"],
                     @"llbracket" :[MTMathAtom atomWithType:kMTMathAtomOpen value:@"\u27e6"],
                     @"llcorner"  :[MTMathAtom atomWithType:kMTMathAtomOpen value:@"\u231e"],
                     @"llparenthesis" :[MTMathAtom atomWithType:kMTMathAtomOpen value:@"\u2987"],
                     @"ulcorner"  :[MTMathAtom atomWithType:kMTMathAtomOpen value:@"\u231c"],
                     
                     // Close
                     @"Rbag"           : [MTMathAtom atomWithType:kMTMathAtomClose value:@"\u27c6"],
                     @"lrcorner"       : [MTMathAtom atomWithType:kMTMathAtomClose value:@"\u231f"],
                     @"rangle"         : [MTMathAtom atomWithType:kMTMathAtomClose value:@"\u27e9"],
                     @"rbag"           : [MTMathAtom atomWithType:kMTMathAtomClose value:@"\u27c6"],
                     @"rceil"          : [MTMathAtom atomWithType:kMTMathAtomClose value:@"\u2309"],
                     @"rfloor"         : [MTMathAtom atomWithType:kMTMathAtomClose value:@"\u230b"],
                     @"rgroup"         : [MTMathAtom atomWithType:kMTMathAtomClose value:@"\u27ef"],
                     @"rrbracket"      : [MTMathAtom atomWithType:kMTMathAtomClose value:@"\u27e7"],
                     @"rrparenthesis"  : [MTMathAtom atomWithType:kMTMathAtomClose value:@"\u2988"],
                     @"urcorner"       : [MTMathAtom atomWithType:kMTMathAtomClose value:@"\u231d"],
                     
                    
                     // Bracket
                     
                     @"Biggr"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@""],
                     @"Bigr"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@""],
                     @"biggr"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@""],
                     @"bigr"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@""],
                     @"Biggl"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@""],
                     @"Bigl"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@""],
                     @"biggl"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@""],
                     @"bigl"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@""],
                     @"Big"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@""],
                     @"big"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@""],
                     @"bmod"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u00a0mod\u00a0"],
                     @"pmod"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u00a0mod\u00a0"],
                     
                      // Arrow and Releation
                     @"Bumpeq"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u224e"],
                     @"Doteq"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2251"],
                     @"Downarrow"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21d3"],
                     @"Leftarrow"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21d0"],
                     @"Leftrightarrow"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21d4"],
                     @"Lleftarrow"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21da"],
                     @"Longleftarrow"           : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u27f8"],
                     @"Longleftrightarrow"      : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u27fa"],
                     @"Longmapsfrom"            : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u27fd"],
                     @"Longmapsto"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u27fe"],
                     @"Longrightarrow"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u27f9"],
                     @"Lsh"                     : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21b0"],
                     @"Mapsfrom"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2906"],
                     @"Mapsto"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2907"],
                     @"Rightarrow"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21d2"],
                     @"Rrightarrow"             : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21db"],
                     @"Rsh"                     : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21b1"],
                     @"Subset"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22d0"],
                     @"Supset"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22d1"],
                     @"Uparrow"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21d1"],
                     @"Updownarrow"             : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21d5"],
                     @"VDash"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22ab"],
                     @"Vdash"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22a9"],
                     @"Vvdash"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22aa"],
                     @"apprge"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2273"],
                     @"apprle"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2272"],
                     @"approx"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2248"],
                     @"approxeq"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u224a"],
                     @"asymp"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u224d"],
                     @"backsim"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u223d"],
                     @"backsimeq"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22cd"],
                     @"barin"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22f6"],
                     @"barleftharpoon"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u296b"],
                     @"barrightharpoon"         : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u296d"],
                     @"between"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u226c"],
                     @"bowtie"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22c8"],
                     @"bumpeq"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u224f"],
                     @"circeq"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2257"],
                     @"coloneq"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2254"],
                     @"cong"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2245"],
                     @"corresponds"             : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2259"],
                     @"curlyeqprec"             : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22de"],
                     @"curlyeqsucc"             : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22df"],
                     @"curvearrowleft"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21b6"],
                     @"curvearrowright"         : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21b7"],
                     @"dashv"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22a3"],
                     @"ddots"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22f1"],
                     @"dlsh"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21b2"],
                     @"doteq"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2250"],
                     @"doteqdot"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2251"],
                     @"downarrow"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2193"],
                     @"downdownarrows"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21ca"],
                     @"downdownharpoons"        : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2965"],
                     @"downharpoonleft"         : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21c3"],
                     @"downharpoonright"        : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21c2"],
                     @"downuparrows"            : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21f5"],
                     @"downupharpoons"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u296f"],
                     @"drsh"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21b3"],
                     @"eqcirc"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2256"],
                     @"eqcolon"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2255"],
                     @"eqsim"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2242"],
                     @"eqslantgtr"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2a96"],
                     @"eqslantless"             : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2a95"],
                     @"equiv"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2261"],
                     @"fallingdotseq"           : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2252"],
                     @"frown"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2322"],
                     @"ge"                      : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2265"],
                     @"geq"                     : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2265"],
                     @"geqq"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2267"],
                     @"geqslant"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2a7e"],
                     @"gets"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2190"],
                     @"gg"                      : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u226b"],
                     @"ggcurly"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2abc"],
                     @"ggg"                     : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22d9"],
                     @"gnapprox"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2a8a"],
                     @"gneq"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2a88"],
                     @"gneqq"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2269"],
                     @"gnsim"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22e7"],
                     @"gtrapprox"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2a86"],
                     @"gtrdot"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22d7"],
                     @"gtreqless"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22db"],
                     @"gtreqqless"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2a8c"],
                     @"gtrless"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2277"],
                     @"gtrsim"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2273"],
                     @"hash"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22d5"],
                     @"hookleftarrow"           : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21a9"],
                     @"hookrightarrow"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21aa"],
                     @"iddots"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22f0"],
                     @"impliedby"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u27f8"],
                     @"implies"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u27f9"],
                     @"in"                      : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2208"],
                     @"le"                      : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2264"],
                     @"leadsto"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21dd"],
                     @"leftarrow"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2190"],
                     @"leftarrowtail"           : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21a2"],
                     @"leftarrowtriangle"       : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21fd"],
                     @"leftbarharpoon"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u296a"],
                     @"leftharpoondown"         : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21bd"],
                     @"leftharpoonup"           : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21bc"],
                     @"leftleftarrows"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21c7"],
                     @"leftleftharpoons"        : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2962"],
                     @"leftrightarrow"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2194"],
                     @"leftrightarrows"         : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21c6"],
                     @"leftrightarrowtriangle"  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21ff"],
                     @"leftrightharpoon"        : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u294a"],
                     @"leftrightharpoons"       : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21cb"],
                     @"leftrightsquigarrow"     : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21ad"],
                     @"leftslice"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2aa6"],
                     @"leftsquigarrow"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21dc"],
                     @"leq"                     : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2264"],
                     @"leqq"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2266"],
                     @"leqslant"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2a7d"],
                     @"lessapprox"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2a85"],
                     @"lessdot"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22d6"],
                     @"lesseqgtr"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22da"],
                     @"lesseqqgtr"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2a8b"],
                     @"lessgtr"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2276"],
                     @"lesssim"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2272"],
                     @"lightning"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21af"],
                     @"ll"                      : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u226a"],
                     @"llcurly"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2abb"],
                     @"lll"                     : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22d8"],
                     @"lnapprox"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2a89"],
                     @"lneq"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2a87"],
                     @"lneqq"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2268"],
                     @"lnsim"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22e6"],
                     @"longleftarrow"           : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u27f5"],
                     @"longleftrightarrow"      : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u27f7"],
                     @"longmapsfrom"            : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u27fb"],
                     @"longmapsto"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u27fc"],
                     @"longrightarrow"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u27f6"],
                     @"looparrowleft"           : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21ab"],
                     @"looparrowright"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21ac"],
                     @"mapsfrom"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21a4"],
                     @"mapsto"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21a6"],
                     @"mid"                     : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2223"],
                     @"models"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22a7"],
                     @"multimap"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22b8"],
                     @"nLeftarrow"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21cd"],
                     @"nLeftrightarrow"         : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21ce"],
                     @"nRightarrow"             : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21cf"],
                     @"nVDash"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22af"],
                     @"nVdash"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22ae"],
                     @"ncong"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2247"],
                     @"ne"                      : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2260"],
                     @"nearrow"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2197"],
                     @"neq"                     : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2260"],
                     @"ngeq"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2271"],
                     @"ngtr"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u226f"],
                     @"ni"                      : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u220b"],
                     @"nleftarrow"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u219a"],
                     @"nleftrightarrow"         : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21ae"],
                     @"nleq"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2270"],
                     @"nless"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u226e"],
                     @"nmid"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2224"],
                     @"notasymp"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u226d"],
                     @"notin"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2209"],
                     @"notowner"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u220c"],
                     @"notslash"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u233f"],
                     @"nparallel"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2226"],
                     @"nprec"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2280"],
                     @"npreceq"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22e0"],
                     @"nrightarrow"             : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u219b"],
                     @"nsim"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2241"],
                     @"nsubseteq"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2288"],
                     @"nsucc"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2281"],
                     @"nsucceq"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22e1"],
                     @"nsupseteq"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2289"],
                     @"ntriangleleft"           : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22ea"],
                     @"ntrianglelefteq"         : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22ec"],
                     @"ntriangleright"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22eb"],
                     @"ntrianglerighteq"        : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22ed"],
                     @"nvDash"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22ad"],
                     @"nvdash"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22ac"],
                     @"nwarrow"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2196"],
                     @"owns"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u220b"],
                     @"parallel"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2225"],
                     @"perp"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u27c2"],
                     @"pitchfork"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22d4"],
                     @"prec"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u227a"],
                     @"precapprox"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2ab7"],
                     @"preccurlyeq"             : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u227c"],
                     @"preceq"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2aaf"],
                     @"precnapprox"             : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2ab9"],
                     @"precnsim"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22e8"],
                     @"precsim"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u227e"],
                     @"propto"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u221d"],
                     @"restriction"             : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21be"],
                     @"rightarrow"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2192"],
                     @"rightarrowtail"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21a3"],
                     @"rightarrowtriangle"      : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21fe"],
                     @"rightbarharpoon"         : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u296c"],
                     @"rightharpoondown"        : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21c1"],
                     @"rightharpoonup"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21c0"],
                     @"rightleftarrows"         : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21c4"],
                     @"rightleftharpoon"        : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u294b"],
                     @"rightleftharpoons"       : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21cc"],
                     @"rightrightarrows"        : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21c9"],
                     @"rightrightharpoons"      : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2964"],
                     @"rightslice"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2aa7"],
                     @"rightsquigarrow"         : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21dd"],
                     @"risingdotseq"            : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2253"],
                     @"searrow"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2198"],
                     @"sim"                     : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u223c"],
                     @"simeq"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2243"],
                     @"smallfrown"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2322"],
                     @"smallsmile"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2323"],
                     @"smile"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2323"],
                     @"sqsubset"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u228f"],
                     @"sqsubseteq"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2291"],
                     @"sqsupset"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2290"],
                     @"sqsupseteq"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2292"],
                     @"subset"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2282"],
                     @"subseteq"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2286"],
                     @"subseteqq"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2ac5"],
                     @"subsetneq"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u228a"],
                     @"subsetneqq"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2acb"],
                     @"succ"                    : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u227b"],
                     @"succapprox"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2ab8"],
                     @"succcurlyeq"             : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u227d"],
                     @"succeq"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2ab0"],
                     @"succnapprox"             : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2aba"],
                     @"succnsim"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22e9"],
                     @"succsim"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u227f"],
                     @"supset"                  : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2283"],
                     @"supseteq"                : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2287"],
                     @"supseteqq"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2ac6"],
                     @"supsetneq"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u228b"],
                     @"supsetneqq"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2acc"],
                     @"swarrow"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2199"],
                     @"to"                      : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2192"],
                     @"trianglelefteq"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22b4"],
                     @"triangleq"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u225c"],
                     @"trianglerighteq"         : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22b5"],
                     @"twoheadleftarrow"        : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u219e"],
                     @"twoheadrightarrow"       : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21a0"],
                     @"unlhd"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22b4"],
                     @"unrhd"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22b5"],
                     @"uparrow"                 : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2191"],
                     @"updownarrow"             : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2195"],
                     @"updownarrows"            : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21c5"],
                     @"updownharpoons"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u296e"],
                     @"upharpoonleft"           : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21bf"],
                     @"upharpoonright"          : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21be"],
                     @"upuparrows"              : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u21c8"],
                     @"upupharpoons"            : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u2963"],
                     @"vDash"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22a8"],
                     @"varpropto"               : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u221d"],
                     @"vartriangleleft"         : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22b2"],
                     @"vartriangleright"        : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22b3"],
                     @"vdash"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22a2"],
                     @"vdots"                   : [MTMathAtom atomWithType:kMTMathAtomRelation value:@"\u22ee"],
                     
                     // operators
                     @"times" : [MTMathAtomFactory times],
                     @"div"   : [MTMathAtomFactory divide],
                     @"Cap"                 :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22d2"],
                     @"Circle"              :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25cb"],
                     @"Cup"                 :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22d3"],
                     @"LHD"                 :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25c0"],
                     @"RHD"                 :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25b6"],
                     @"amalg"               :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2a3f"],
                     @"ast"                 :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2217"],
                     @"barwedge"            :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22bc"],
                     @"bigcirc"            :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25ef"],
                     @"bigtriangledown"     :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25bd"],
                     @"bigtriangleup"       :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25b3"],
                     @"bindnasrepma"        :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u214b"],
                     @"blacklozenge"        :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u29eb"],
                     @"blacktriangledown"   :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25be"],
                     @"blacktriangleleft"   :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25c2"],
                     @"blacktriangleright"  :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25b8"],
                     @"blacktriangleup"     :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25b4"],
                     @"boxast"              :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u29c6"],
                     @"boxbar"              :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25eb"],
                     @"boxbox"              :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u29c8"],
                     @"boxbslash"           :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u29c5"],
                     @"boxcircle"           :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u29c7"],
                     @"boxdot"              :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22a1"],
                     @"boxminus"            :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u229f"],
                     @"boxplus"             :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u229e"],
                     @"boxslash"            :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u29c4"],
                     @"boxtimes"            :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22a0"],
                     @"bullet"              :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2219"],
                     @"cap"                 :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2229"],
                     @"cdot"                :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22c5"],
                     @"circ"                :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2218"],
                     @"circledast"          :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u229b"],
                     @"circledcirc"         :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u229a"],
                     @"circleddash"         :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u229d"],
                     @"cup"                 :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u222a"],
                     @"curlyvee"            :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22ce"],
                     @"curlywedge"          :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22cf"],
                     @"dagger"              :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2020"],
                     @"ddagger"             :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2021"],
                     @"diamond"             :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22c4"],
                     @"divideontimes"       :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22c7"],
                     @"dotplus"             :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2214"],
                     @"doublebarwedge"      :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2a5e"],
                     @"intercal"            :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22ba"],
                     @"interleave"          :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2af4"],
                     @"land"                :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2227"],
                     @"leftthreetimes"      :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22cb"],
                     @"lhd"                 :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25c1"],
                     @"lor"                 :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2228"],
                     @"ltimes"              :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22c9"],
                     @"mp"                  :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2213"],
                     @"odot"                :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2299"],
                     @"ominus"              :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2296"],
                     @"oplus"               :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2295"],
                     @"oslash"              :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2298"],
                     @"otimes"              :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2297"],
                     @"pm"                  :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u00b1"],
                     @"rhd"                 :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25b7"],
                     @"rightthreetimes"     :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22cc"],
                     @"rtimes"              :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22ca"],
                     @"setminus"            :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u29f5"],
                     @"slash"               :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2215"],
                     @"smallsetminus"       :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2216"],
                     @"smalltriangledown"   :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25bf"],
                     @"smalltriangleleft"   :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25c3"],
                     @"smalltriangleright"  :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25b9"],
                     @"smalltriangleup"     :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25b5"],
                     @"sqcap"               :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2293"],
                     @"sqcup"               :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2294"],
                     @"sslash"              :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2afd"],
                     @"star"                :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22c6"],
                     @"talloblong"          :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2afe"],
                     @"triangle"            :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25b3"],
                     @"triangledown"        :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25bf"],
                     @"triangleleft"        :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25c3"],
                     @"triangleright"       :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25b9"],
                     @"uplus"               :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u228e"],
                     @"vartriangle"         :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u25b3"],
                     @"vee"                 :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2228"],
                     @"veebar"              :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u22bb"],
                     @"wedge"               :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2227"],
                     @"wr"                  :[MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:@"\u2240"],
                     
                     // No limit operators
                     @"log" : [MTMathAtomFactory operatorWithName:@"log" limits:NO],
                     @"lg" : [MTMathAtomFactory operatorWithName:@"lg" limits:NO],
                     @"ln" : [MTMathAtomFactory operatorWithName:@"ln" limits:NO],
                     @"sin" : [MTMathAtomFactory operatorWithName:@"sin" limits:NO],
                     @"arcsin" : [MTMathAtomFactory operatorWithName:@"arcsin" limits:NO],
                     @"sinh" : [MTMathAtomFactory operatorWithName:@"sinh" limits:NO],
                     @"cos" : [MTMathAtomFactory operatorWithName:@"cos" limits:NO],
                     @"arccos" : [MTMathAtomFactory operatorWithName:@"arccos" limits:NO],
                     @"cosh" : [MTMathAtomFactory operatorWithName:@"cosh" limits:NO],
                     @"tan" : [MTMathAtomFactory operatorWithName:@"tan" limits:NO],
                     @"arctan" : [MTMathAtomFactory operatorWithName:@"arctan" limits:NO],
                     @"tanh" : [MTMathAtomFactory operatorWithName:@"tanh" limits:NO],
                     @"cot" : [MTMathAtomFactory operatorWithName:@"cot" limits:NO],
                     @"coth" : [MTMathAtomFactory operatorWithName:@"coth" limits:NO],
                     @"sec" : [MTMathAtomFactory operatorWithName:@"sec" limits:NO],
                     @"csc" : [MTMathAtomFactory operatorWithName:@"csc" limits:NO],
                     @"arg" : [MTMathAtomFactory operatorWithName:@"arg" limits:NO],
                     @"ker" : [MTMathAtomFactory operatorWithName:@"ker" limits:NO],
                     @"dim" : [MTMathAtomFactory operatorWithName:@"dim" limits:NO],
                     @"hom" : [MTMathAtomFactory operatorWithName:@"hom" limits:NO],
                     @"exp" : [MTMathAtomFactory operatorWithName:@"exp" limits:NO],
                     @"deg" : [MTMathAtomFactory operatorWithName:@"deg" limits:NO],
                     
                     // Limit operators
                     @"lim" : [MTMathAtomFactory operatorWithName:@"lim" limits:YES],
                     @"limsup" : [MTMathAtomFactory operatorWithName:@"lim sup" limits:YES],
                     @"liminf" : [MTMathAtomFactory operatorWithName:@"lim inf" limits:YES],
                     @"max" : [MTMathAtomFactory operatorWithName:@"max" limits:YES],
                     @"min" : [MTMathAtomFactory operatorWithName:@"min" limits:YES],
                     @"sup" : [MTMathAtomFactory operatorWithName:@"sup" limits:YES],
                     @"inf" : [MTMathAtomFactory operatorWithName:@"inf" limits:YES],
                     @"det" : [MTMathAtomFactory operatorWithName:@"det" limits:YES],
                     @"Pr" : [MTMathAtomFactory operatorWithName:@"Pr" limits:YES],
                     @"gcd" : [MTMathAtomFactory operatorWithName:@"gcd" limits:YES],
                     
                     // Large operators
                     @"Join"              : [MTMathAtomFactory operatorWithName:@"\u2a1d" limits:YES],
                     @"bigcap"            : [MTMathAtomFactory operatorWithName:@"\u22c2" limits:YES],
                     @"bigcup"            : [MTMathAtomFactory operatorWithName:@"\u22c3" limits:YES],
                     @"biginterleave"     : [MTMathAtomFactory operatorWithName:@"\u2afc" limits:YES],
                     @"bigodot"           : [MTMathAtomFactory operatorWithName:@"\u2a00" limits:YES],
                     @"bigoplus"          : [MTMathAtomFactory operatorWithName:@"\u2a01" limits:YES],
                     @"bigotimes"         : [MTMathAtomFactory operatorWithName:@"\u2a02" limits:YES],
                     @"bigsqcup"          : [MTMathAtomFactory operatorWithName:@"\u2a06" limits:YES],
                     @"biguplus"          : [MTMathAtomFactory operatorWithName:@"\u2a04" limits:YES],
                     @"bigvee"            : [MTMathAtomFactory operatorWithName:@"\u22c1" limits:YES],
                     @"bigwedge"          : [MTMathAtomFactory operatorWithName:@"\u22c0" limits:YES],
                     @"coprod"            : [MTMathAtomFactory operatorWithName:@"\u2210" limits:YES],
                     @"fatsemi"           : [MTMathAtomFactory operatorWithName:@"\u2a1f" limits:YES],
                     @"fint"              : [MTMathAtomFactory operatorWithName:@"\u2a0f" limits:YES],
                     @"iiiint"            : [MTMathAtomFactory operatorWithName:@"\u2a0c" limits:YES],
                     @"iiint"             : [MTMathAtomFactory operatorWithName:@"\u222d" limits:YES],
                     @"iint"              : [MTMathAtomFactory operatorWithName:@"\u222c" limits:YES],
                     @"int"               : [MTMathAtomFactory operatorWithName:@"\u222b" limits:YES],
                     @"oiint"             : [MTMathAtomFactory operatorWithName:@"\u222f" limits:YES],
                     @"oint"              : [MTMathAtomFactory operatorWithName:@"\u222e" limits:YES],
                     @"ointctrclockwise"  : [MTMathAtomFactory operatorWithName:@"\u2233" limits:YES],
                     @"prod"              : [MTMathAtomFactory operatorWithName:@"\u220f" limits:YES],
                     @"sqint"             : [MTMathAtomFactory operatorWithName:@"\u2a16" limits:YES],
                     @"sum"               : [MTMathAtomFactory operatorWithName:@"\u2211" limits:YES],
                     @"varointclockwise"  : [MTMathAtomFactory operatorWithName:@"\u2232" limits:YES],
                     
                     // Latex command characters
                     @"{" : [MTMathAtom atomWithType:kMTMathAtomOpen value:@"{"],
                     @"}" : [MTMathAtom atomWithType:kMTMathAtomClose value:@"}"],
                     @"$" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"$"],
                     @"&" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"&"],
                     @"#" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"#"],
                     @"%" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"%"],
                     @"_" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"_"],
                     @" " : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@" "],
                     @"backslash" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\\"],
                     
                     // Punctuation
                     // Note: \colon is different from : which is a relation
                     @"colon" : [MTMathAtom atomWithType:kMTMathAtomPunctuation value:@":"],
                     @"cdotp" : [MTMathAtom atomWithType:kMTMathAtomPunctuation value:@"\u00B7"],
                     
                     // Other symbols
                     @"degree" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u00B0"],
                     @"neg" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u00AC"],
                     @"angstrom" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u00C5"],
                     @"|" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2016"],
                     @"vert" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"|"],
                     @"ldots" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2026"],
                     @"prime" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2032"],
                     @"hbar" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u210F"],
                     @"Im" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2111"],
                     @"ell" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2113"],
                     @"wp" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2118"],
                     @"Re" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u211C"],
                     @"mho" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2127"],
                     @"aleph" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2135"],
                     @"forall" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2200"],
                     @"exists" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2203"],
                     @"emptyset" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2205"],
                     @"nabla" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2207"],
                     @"infty" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u221E"],
                     @"angle" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2220"],
                     @"top" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u22A4"],
                     @"bot" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u22A5"],
                     @"vdots" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u22EE"],
                     @"cdots" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u22EF"],
                     @"ddots" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u22F1"],
                     @"triangle" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u25B3"],
                     @"imath" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\U0001D6A4"],
                     @"jmath" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\U0001D6A5"],
                     @"partial" : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\U0001D715"],
                     
                     
                     @"AC"                : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u223f"],
                     @"APLcomment"        : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u235d"],
                     @"APLdownarrowbox"   : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2357"],
                     @"APLinput"          : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u235e"],
                     @"APLinv"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2339"],
                     @"APLleftarrowbox"   : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2347"],
                     @"APLlog"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u235f"],
                     @"APLrightarrowbox"  : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2348"],
                     @"APLuparrowbox"     : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2350"],
                     @"Aries"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2648"],
                     @"CIRCLE"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u25cf"],
                     @"CheckedBox"        : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2611"],
                     @"Diamond"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u25c7"],
                     @"Finv"              : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2132"],
                     @"Game"              : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2141"],
                     @"Gemini"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u264a"],
                     @"Jupiter"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2643"],
                     @"LEFTCIRCLE"        : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u25d6"],
                     @"LEFTcircle"        : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u25d0"],
                     @"Leo"               : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u264c"],
                     @"Libra"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u264e"],
                     @"Mars"              : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2642"],
                     @"Mercury"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u263f"],
                     @"Neptune"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2646"],
                     @"Pluto"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2647"],
                     @"RIGHTCIRCLE"       : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u25d7"],
                     @"RIGHTcircle"       : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u25d1"],
                     @"Saturn"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2644"],
                     @"Scorpio"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u264f"],
                     @"Square"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2610"],
                     @"Sun"               : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2609"],
                     @"Taurus"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2649"],
                     @"Uranus"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2645"],
                     @"Venus"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2640"],
                     @"XBox"              : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2612"],
                     @"Yup"               : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2144"],
                     @"angle"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2220"],
                     @"aquarius"          : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2652"],
                     @"aries"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2648"],
                     @"ast"               : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"*"],
                     @"backepsilon"       : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u03f6"],
                     @"backprime"         : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2035"],
                     @"because"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2235"],
                     @"bigstar"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2605"],
                     @"binampersand"      : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"&"],
                     @"blacklozenge"      : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2b27"],
                     @"blacksmiley"       : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u263b"],
                     @"blacksquare"       : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u25fc"],
                     @"bot"               : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u22a5"],
                     @"boy"               : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2642"],
                     @"cancer"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u264b"],
                     @"capricornus"       : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2651"],
                     @"cdots"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u22ef"],
                     @"cent"              : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u00a2"],
                     @"centerdot"         : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2b1d"],
                     @"checkmark"         : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2713"],
                     @"circlearrowleft"   : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u21ba"],
                     @"circlearrowright"  : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u21bb"],
                     @"circledR"          : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u00ae"],
                     @"circledcirc"       : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u25ce"],
                     @"clubsuit"          : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2663"],
                     @"complement"        : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2201"],
                     @"dasharrow"         : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u21e2"],
                     @"dashleftarrow"     : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u21e0"],
                     @"dashrightarrow"    : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u21e2"],
                     @"diameter"          : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2300"],
                     @"diamondsuit"       : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2662"],
                     @"earth"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2641"],
                     @"exists"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2203"],
                     @"female"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2640"],
                     @"flat"              : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u266d"],
                     @"forall"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2200"],
                     @"fourth"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2057"],
                     @"frownie"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2639"],
                     @"gemini"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u264a"],
                     @"girl"              : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2640"],
                     @"heartsuit"         : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2661"],
                     @"infty"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u221e"],
                     @"invneg"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2310"],
                     @"jupiter"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2643"],
                     @"ldots"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2026"],
                     @"leftmoon"          : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u263e"],
                     @"leftturn"          : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u21ba"],
                     @"leo"               : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u264c"],
                     @"libra"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u264e"],
                     @"lnot"              : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u00ac"],
                     @"lozenge"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u25ca"],
                     @"male"              : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2642"],
                     @"maltese"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2720"],
                     @"mathdollar"        : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"$"],
                     @"measuredangle"     : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2221"],
                     @"mercury"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u263f"],
                     @"mho"               : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2127"],
                     @"nabla"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2207"],
                     @"natural"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u266e"],
                     @"neg"               : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u00ac"],
                     @"neptune"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2646"],
                     @"nexists"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2204"],
                     @"notbackslash"      : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2340"],
                     @"partial"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2202"],
                     @"pisces"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2653"],
                     @"pluto"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2647"],
                     @"pounds"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u00a3"],
                     @"prime"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2032"],
                     @"quarternote"       : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2669"],
                     @"rightmoon"         : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u263d"],
                     @"rightturn"         : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u21bb"],
                     @"sagittarius"       : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2650"],
                     @"saturn"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2644"],
                     @"scorpio"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u264f"],
                     @"second"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2033"],
                     @"sharp"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u266f"],
                     @"sim"               : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"~"],
                     @"slash"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"/"],
                     @"smiley"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u263a"],
                     @"spadesuit"         : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2660"],
                     @"spddot"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u00a8"],
                     @"sphat"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"^"],
                     @"sphericalangle"    : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2222"],
                     @"sptilde"           : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"~"],
                     @"square"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u25fb"],
                     @"sun"               : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u263c"],
                     @"taurus"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2649"],
                     @"therefore"         : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2234"],
                     @"third"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2034"],
                     @"top"               : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u22a4"],
                     @"triangleleft"      : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u25c5"],
                     @"triangleright"     : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u25bb"],
                     @"twonotes"          : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u266b"],
                     @"uranus"            : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2645"],
                     @"varEarth"          : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2641"],
                     @"varnothing"        : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2205"],
                     @"virgo"             : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u264d"],
                     @"wasylozenge"       : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2311"],
                     @"wasytherefore"     : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u2234"],
                     @"yen"               : [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@"\u00a5"],
                     
                     // Spacing
                     @"," : [[MTMathSpace alloc] initWithSpace:3],
                     @">" : [[MTMathSpace alloc] initWithSpace:4],
                     @";" : [[MTMathSpace alloc] initWithSpace:5],
                     @"!" : [[MTMathSpace alloc] initWithSpace:-3],
                     @"quad" : [[MTMathSpace alloc] initWithSpace:18],  // quad = 1em = 18mu
                     @"qquad" : [[MTMathSpace alloc] initWithSpace:36], // qquad = 2em
                     
                     // Style
                     @"displaystyle" : [[MTMathStyle alloc] initWithStyle:kMTLineStyleDisplay],
                     @"textstyle" : [[MTMathStyle alloc] initWithStyle:kMTLineStyleText],
                     @"scriptstyle" : [[MTMathStyle alloc] initWithStyle:kMTLineStyleScript],
                     @"scriptscriptstyle" : [[MTMathStyle alloc] initWithStyle:kMTLineStyleScriptScript],
                     }];
        
    }
    return commands;
}

+ (NSDictionary*) aliases
{
    static NSDictionary* aliases = nil;
    if (!aliases) {
        aliases = @{
                    @"lnot" : @"neg",
                    @"land" : @"wedge",
                    @"lor" : @"vee",
                    @"ne" : @"neq",
                    @"le" : @"leq",
                    @"ge" : @"geq",
                    @"lbrace" : @"{",
                    @"rbrace" : @"}",
                    @"Vert" : @"|",
                    @"gets" : @"leftarrow",
                    @"to" : @"rightarrow",
                    @"iff" : @"Longleftrightarrow",
                    @"AA" : @"angstrom"
                    };
    }
    return aliases;
}

+ (NSMutableDictionary<NSString*, NSString*>*) textToLatexSymbolNames
{
    static NSMutableDictionary<NSString*, NSString*>* textToCommands = nil;
    if (!textToCommands) {
        NSDictionary* commands = [self supportedLatexSymbols];
        textToCommands = [NSMutableDictionary dictionaryWithCapacity:commands.count];
        for (NSString* command in commands) {
            MTMathAtom* atom = commands[command];
            if (atom.nucleus.length == 0) {
                continue;
            }
            
            NSString* existingCommand = textToCommands[atom.nucleus];
            if (existingCommand) {
                // If there are 2 commands for the same symbol, choose one deterministically.
                if (command.length > existingCommand.length) {
                    // Keep the shorter command
                    continue;
                } else if (command.length == existingCommand.length) {
                    // If the length is the same, keep the alphabetically first
                    if ([command compare:existingCommand] == NSOrderedDescending) {
                        continue;
                    }
                }
            }
            // In other cases replace the command.
            textToCommands[atom.nucleus] = command;
        }
    }
    return textToCommands;
}

+ (NSDictionary<NSString*, NSString*>*) accents
{
    static NSDictionary* accents = nil;
    if (!accents) {
        accents = @{
            @"acute"               :@"\u0301",
            @"bar"                 :@"\u0304",
            @"breve"               :@"\u0306",
            @"check"               :@"\u030c",
            @"ddddot"              :@"\u20dc",
            @"dddot"               :@"\u20db",
            @"ddot"                :@"\u0308",
            @"dot"                 :@"\u0307",
            @"grave"               :@"\u0300",
            @"hat"                 :@"\u0302",
            @"mathring"            :@"\u030a",
            @"not"                 :@"\u0338",
            @"overleftarrow"       :@"\u20d6",
            @"overleftrightarrow"  :@"\u20e1",
            @"overline"            :@"\u0305",
            @"overrightarrow"      :@"\u20d7",
            @"tilde"               :@"\u0303",
            @"underbar"            :@"\u0331",
            @"underleftarrow"      :@"\u20ee",
            @"underline"           :@"\u0332",
            @"underrightarrow"     :@"\u20ef",
            @"vec"                 :@"\u20d7",
            @"widehat"             :@"\u0302",
            @"widetilde"           :@"\u0303",
            @"overbrace"           :@"\u23de",
            @"wideparen"           :@"\u23dc",
        };
    }
    return accents;
}

+ (NSDictionary*) accentValueToName
{
    static NSDictionary* accentToCommands = nil;
    if (!accentToCommands) {
        NSDictionary* accents = [self accents];
        NSMutableDictionary* mutableDict = [NSMutableDictionary dictionaryWithCapacity:accents.count];
        for (NSString* command in accents) {
            NSString* acc = accents[command];
            NSString* existingCommand = mutableDict[acc];
            if (existingCommand) {
                if (command.length > existingCommand.length) {
                    // Keep the shorter command
                    continue;
                } else if (command.length == existingCommand.length) {
                    // If the length is the same, keep the alphabetically first
                    if ([command compare:existingCommand] == NSOrderedDescending) {
                        continue;
                    }
                }
            }
            // In other cases replace the command.
            mutableDict[acc] = command;
        }
        accentToCommands = [mutableDict copy];
    }
    return accentToCommands;
}

+(NSDictionary<NSString*, NSString*> *) delimiters
{
    static NSDictionary* delims = nil;
    if (!delims) {
        delims = @{
//                   @"\Bigg" : @"",
//                   @"\Big" : @"",
//                   @"\bigg" : @"",
//                   @"\big" :@"",
                   @"." : @"", // . means no delimiter
                   @"(" : @"(",
                   @")" : @")",
                   @"[" : @"[",
                   @"]" : @"]",
                   @"<" : @"\u2329",
                   @">" : @"\u232A",
                   @"/" : @"/",
                   @"\\" : @"\\",
                   @"|" : @"|",
                   @"lgroup" : @"\u27EE",
                   @"rgroup" : @"\u27EF",
                   @"||" : @"\u2016",
                   @"Vert" : @"\u2016",
                   @"vert" : @"|",
                   @"uparrow" : @"\u2191",
                   @"downarrow" : @"\u2193",
                   @"updownarrow" : @"\u2195",
                   @"Uparrow" : @"21D1",
                   @"Downarrow" : @"21D3",
                   @"Updownarrow" : @"21D5",
                   @"backslash" : @"\\",
                   @"rangle" : @"\u232A",
                   @"langle" : @"\u2329",
                   @"rbrace" : @"}",
                   @"}" : @"}",
                   @"{" : @"{",
                   @"lbrace" : @"{",
                   @"lceil" : @"\u2308",
                   @"rceil" : @"\u2309",
                   @"lfloor" : @"\u230A",
                   @"rfloor" : @"\u230B",
                   };
    }
    return delims;
}

+ (NSDictionary*) delimValueToName
{
    static NSDictionary* delimToCommands = nil;
    if (!delimToCommands) {
        NSDictionary* delims = [self delimiters];
        NSMutableDictionary* mutableDict = [NSMutableDictionary dictionaryWithCapacity:delims.count];
        for (NSString* command in delims) {
            NSString* delim = delims[command];
            NSString* existingCommand = mutableDict[delim];
            if (existingCommand) {
                if (command.length > existingCommand.length) {
                    // Keep the shorter command
                    continue;
                } else if (command.length == existingCommand.length) {
                    // If the length is the same, keep the alphabetically first
                    if ([command compare:existingCommand] == NSOrderedDescending) {
                        continue;
                    }
                }
            }
            // In other cases replace the command.
            mutableDict[delim] = command;
        }
        delimToCommands = [mutableDict copy];
    }
    return delimToCommands;
}


+(NSDictionary<NSString*, NSNumber*> *) fontStyles
{
    static NSDictionary<NSString*, NSNumber*>* fontStyles = nil;
    if (!fontStyles) {
        fontStyles = @{
                       @"mathnormal" : @(kMTFontStyleDefault),
                       @"mathrm": @(kMTFontStyleRoman),
                       @"textrm": @(kMTFontStyleRoman),
                       @"rm": @(kMTFontStyleRoman),
                       @"mathbf": @(kMTFontStyleBold),
                       @"bf": @(kMTFontStyleBold),
                       @"textbf": @(kMTFontStyleBold),
                       @"mathcal": @(kMTFontStyleCaligraphic),
                       @"cal": @(kMTFontStyleCaligraphic),
                       @"mathtt": @(kMTFontStyleTypewriter),
                       @"texttt": @(kMTFontStyleTypewriter),
                       @"mathit": @(kMTFontStyleItalic),
                       @"textit": @(kMTFontStyleItalic),
                       @"mit": @(kMTFontStyleItalic),
                       @"mathsf": @(kMTFontStyleSansSerif),
                       @"textsf": @(kMTFontStyleSansSerif),
                       @"mathfrak": @(kMTFontStyleFraktur),
                       @"frak": @(kMTFontStyleFraktur),
                       @"mathbb": @(kMTFontStyleBlackboard),
                       @"mathbfit": @(kMTFontStyleBoldItalic),
                       @"bm": @(kMTFontStyleBoldItalic),
                       @"text": @(kMTFontStyleRoman),
                   };
    }
    return fontStyles;
}

@end
