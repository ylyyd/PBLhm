AppStorage.setOrCreate('themeMode', 0)
AppStorage.setOrCreate('systemIsDark', false)

// ─── Global Text Style Extensions ────────────────────────────
// Usage: Text('Hello').titleStyle()
// Available after: import { AppColor } from '../common/StyleConstants'
// ──────────────────────────────────────────────────────────────

@Extend(Text) function titleStyle() {
  .fontSize(AppFont.TITLE)
  .fontWeight(FontWeight.Bold)
  .fontColor(AppColor.textPrimary())
}

@Extend(Text) function bodyStyle() {
  .fontSize(AppFont.BODY)
  .fontWeight(FontWeight.Regular)
  .fontColor(AppColor.textPrimary())
}

@Extend(Text) function captionStyle() {
  .fontSize(AppFont.SMALL)
  .fontWeight(FontWeight.Regular)
  .fontColor(AppColor.textTertiary())
}

@Extend(Text) function priceStyle() {
  .fontSize(AppFont.PRICE)
  .fontWeight(FontWeight.Bold)
  .fontColor(AppColor.PRIMARY)
}

@Extend(Text) function labelStyle() {
  .fontSize(AppFont.SMALL)
  .fontWeight(FontWeight.Medium)
  .fontColor(AppColor.textSecondary())
}

@Extend(Text) function discountStyle() {
  .fontSize(AppFont.XS)
  .fontWeight(FontWeight.Medium)
  .fontColor(AppColor.CANCEL)
}

// ──────────────────────────────────────────────────────────────

export function isDarkMode(): boolean {
  let mode = AppStorage.get<number>('themeMode') ?? 0
  if (mode === 2) return true
  if (mode === 1 && (AppStorage.get<boolean>('systemIsDark') ?? false)) return true
  return false
}

export function setThemeMode(mode: number): void {
  AppStorage.set('themeMode', mode)
}

export function getThemeMode(): number {
  return AppStorage.get<number>('themeMode') ?? 0
}

export function setSystemIsDark(isDark: boolean): void {
  AppStorage.set('systemIsDark', isDark)
}

export function getSystemIsDark(): boolean {
  return AppStorage.get<boolean>('systemIsDark') ?? false
}

export class AppColor {
  static readonly PRIMARY: string = '#FF5722'
  static readonly PRIMARY_LIGHT: string = '#FF8A65'
  static readonly PRIMARY_BG: string = '#FFF0EB'
  static readonly PRIMARY_BG_DARK: string = '#3D1A0A'
  static readonly BACKGROUND: string = '#F5F5F5'
  static readonly BACKGROUND_DARK: string = '#121212'
  static readonly CARD_BG: string = '#FFFFFF'
  static readonly CARD_BG_DARK: string = '#1E1E1E'
  static readonly TEXT_PRIMARY: string = '#1A1A1A'
  static readonly TEXT_PRIMARY_DARK: string = '#E0E0E0'
  static readonly TEXT_SECONDARY: string = '#666666'
  static readonly TEXT_SECONDARY_DARK: string = '#AAAAAA'
  static readonly TEXT_TERTIARY: string = '#999999'
  static readonly TEXT_TERTIARY_DARK: string = '#888888'
  static readonly TEXT_DISABLED: string = '#CCCCCC'
  static readonly TEXT_DISABLED_DARK: string = '#555555'
  static readonly DIVIDER: string = '#F0F0F0'
  static readonly DIVIDER_DARK: string = '#333333'
  static readonly CANCEL: string = '#FF4444'
  static readonly CANCEL_DARK: string = '#CF6679'
  static readonly SUCCESS: string = '#4CAF50'
  static readonly SUCCESS_DARK: string = '#81C784'
  static readonly WHITE: string = '#FFFFFF'
  static readonly OVERLAY: string = '#60000000'
  static readonly OVERLAY_DARK: string = '#80000000'
  static readonly TAB_INACTIVE: string = '#F0F0F0'
  static readonly TAB_INACTIVE_DARK: string = '#333333'
  static readonly INPUT_BG: string = '#F5F5F5'
  static readonly INPUT_BG_DARK: string = '#2C2C2C'
  static readonly BORDER: string = '#E0E0E0'
  static readonly BORDER_DARK: string = '#444444'
  static readonly STATUS_BLUE: string = '#2196F3'
  static readonly STATUS_BLUE_DARK: string = '#64B5F6'
  static readonly STATUS_PINK: string = '#E91E63'
  static readonly STATUS_PINK_DARK: string = '#F48FB1'
  static readonly STAR: string = '#FFD700'
  static readonly STATUS_BG_GREEN: string = '#E8F5E9'
  static readonly STATUS_BG_GREEN_DARK: string = '#1B3D1B'
  static readonly STATUS_BG_RED: string = '#FFEBEE'
  static readonly STATUS_BG_RED_DARK: string = '#3D1B1B'
  static readonly TEXT_DISABLED_LIGHT: string = '#BBBBBB'
  static readonly TEXT_DISABLED_LIGHT_DARK: string = '#555555'
  static readonly TRANSPARENT: string = '#00000000'
  static readonly OVERLAY_HEAVY: string = '#F0000000'
  static readonly BADGE_WHITE: string = '#33FFFFFF'
  static readonly SHADOW_LIGHT: string = '#15000000'
  static readonly SHADOW_LIGHT_DARK: string = '#44000000'
  static readonly SHADOW_TAB: string = '#20000000'
  static readonly SHADOW_TAB_DARK: string = '#44000000'
  static readonly PRIMARY_ALPHA: string = '#30FF5722'

  static bg(): string {
    return isDarkMode() ? AppColor.BACKGROUND_DARK : AppColor.BACKGROUND
  }

  static cardBg(): string {
    return isDarkMode() ? AppColor.CARD_BG_DARK : AppColor.CARD_BG
  }

  static textPrimary(): string {
    return isDarkMode() ? AppColor.TEXT_PRIMARY_DARK : AppColor.TEXT_PRIMARY
  }

  static textSecondary(): string {
    return isDarkMode() ? AppColor.TEXT_SECONDARY_DARK : AppColor.TEXT_SECONDARY
  }

  static textTertiary(): string {
    return isDarkMode() ? AppColor.TEXT_TERTIARY_DARK : AppColor.TEXT_TERTIARY
  }

  static divider(): string {
    return isDarkMode() ? AppColor.DIVIDER_DARK : AppColor.DIVIDER
  }

  static inputBg(): string {
    return isDarkMode() ? AppColor.INPUT_BG_DARK : AppColor.INPUT_BG
  }

  static tabInactive(): string {
    return isDarkMode() ? AppColor.TAB_INACTIVE_DARK : AppColor.TAB_INACTIVE
  }

  static border(): string {
    return isDarkMode() ? AppColor.BORDER_DARK : AppColor.BORDER
  }

  static primaryBg(): string {
    return isDarkMode() ? AppColor.PRIMARY_BG_DARK : AppColor.PRIMARY_BG
  }

  static statusBlue(): string {
    return isDarkMode() ? AppColor.STATUS_BLUE_DARK : AppColor.STATUS_BLUE
  }

  static statusPink(): string {
    return isDarkMode() ? AppColor.STATUS_PINK_DARK : AppColor.STATUS_PINK
  }

  static statusBgGreen(): string {
    return isDarkMode() ? AppColor.STATUS_BG_GREEN_DARK : AppColor.STATUS_BG_GREEN
  }

  static statusBgRed(): string {
    return isDarkMode() ? AppColor.STATUS_BG_RED_DARK : AppColor.STATUS_BG_RED
  }

  static textDisabledLight(): string {
    return isDarkMode() ? AppColor.TEXT_DISABLED_LIGHT_DARK : AppColor.TEXT_DISABLED_LIGHT
  }

  static shadowLight(): string {
    return isDarkMode() ? AppColor.SHADOW_LIGHT_DARK : AppColor.SHADOW_LIGHT
  }

  static shadowTab(): string {
    return isDarkMode() ? AppColor.SHADOW_TAB_DARK : AppColor.SHADOW_TAB
  }
}

export class AppRadius {
  static readonly XS: number = 4
  static readonly SM: number = 8
  static readonly MD: number = 14
  static readonly PILL: number = 16
  static readonly LG: number = 20
  static readonly BTN: number = 25
  static readonly XL: number = 26
  static readonly CIRCLE: number = 100
}

export class AppFont {
  static readonly LARGE: number = 36
  static readonly PRICE: number = 22
  static readonly TITLE: number = 20
  static readonly SUBTITLE: number = 18
  static readonly BODY: number = 16
  static readonly SMALL: number = 13
  static readonly XS: number = 11
  static readonly XXS: number = 10
}

export class SortOption {
  static readonly DEFAULT: string = '默认'
  static readonly PRICE_ASC: string = '价格从低到高'
  static readonly PRICE_DESC: string = '价格从高到低'
  static readonly SALES: string = '销量'
  static readonly RATING: string = '评分'
}

// ─── Shadow Elevation Tokens ──────────────────────────────────
// Usage: .shadow(AppShadow.mid())
// ═══════════════════════════════════════════════════════════════

export interface ShadowConfig {
  radius: number
  color: string
  offsetX: number
  offsetY: number
}

export class AppShadow {
  static low(): ShadowConfig {
    return { radius: 2, color: AppCard.shadowColor(), offsetX: 0, offsetY: 1 }
  }
  static mid(): ShadowConfig {
    return { radius: 4, color: AppCard.shadowColor(), offsetX: 0, offsetY: 2 }
  }
  static high(): ShadowConfig {
    return { radius: 6, color: AppCard.shadowColor(), offsetX: 0, offsetY: 2 }
  }
  static top(): ShadowConfig {
    return { radius: 6, color: AppCard.shadowColor(), offsetX: 0, offsetY: -3 }
  }
}

// ──────────────────────────────────────────────────────────────

export class AppCard {
  /** Card inner padding */
  static readonly PADDING: number = 12
  /** Card border radius */
  static readonly RADIUS: number = AppRadius.LG
  /** Card shadow elevation (vp) */
  static readonly ELEVATION: number = 4
  /** Card shadow color */
  static readonly SHADOW_COLOR: string = '#22000000'
  /** Card shadow color (dark) */
  static readonly SHADOW_COLOR_DARK: string = '#44000000'

  static shadowColor(): string {
    return isDarkMode() ? AppCard.SHADOW_COLOR_DARK : AppCard.SHADOW_COLOR
  }
}

// ─── Layout Container Tokens ──────────────────────────────────
// Standard page content width → '92%'
// ═══════════════════════════════════════════════════════════════

export class AppContainer {
  /** @deprecated Use CONTENT_WIDTH instead */
  static readonly WIDTH: string = '92%'
  /** Standard page content width */
  static readonly CONTENT_WIDTH: string = '92%'
  /** Form / overlay panel width */
  static readonly FORM_WIDTH: string = '88%'
  /** Dialog / modal width */
  static readonly DIALOG_WIDTH: string = '80%'
  /** Full width */
  static readonly FULL_WIDTH: string = '100%'
  /** Full height */
  static readonly FULL_HEIGHT: string = '100%'
}

// ─── Button Tokens ────────────────────────────────────────────
// Primary: 44vp | Large: 52vp | Input-btn: 48vp
// ═══════════════════════════════════════════════════════════════

export class AppButton {
  /** @deprecated Use PRIMARY_HEIGHT instead */
  static readonly MEDIUM_HEIGHT: number = 44
  /** Standard primary button height */
  static readonly PRIMARY_HEIGHT: number = 44
  /** Large / CTA button height */
  static readonly LARGE_HEIGHT: number = 52
  /** Inline input-adjacent button height */
  static readonly INPUT_HEIGHT: number = 48
  /** Small / secondary button height */
  static readonly SMALL_HEIGHT: number = 32
  /** Primary button border radius (pill) */
  static readonly PRIMARY_RADIUS: number = 22
  /** Default button font size */
  static readonly FONT_SIZE: number = 15
  /** Small button font size */
  static readonly SMALL_FONT_SIZE: number = 13
}

// ─── Input Tokens ─────────────────────────────────────────────
// Standard text input dimensions
// ═══════════════════════════════════════════════════════════════

export class AppInput {
  /** Default input height */
  static readonly HEIGHT: number = 52
  /** Input border radius */
  static readonly RADIUS: number = AppRadius.XL
  /** Left padding inside input */
  static readonly PADDING_LEFT: number = 16
  /** Input font size */
  static readonly FONT_SIZE: number = 16
  /** Small input height (search bar, inline) */
  static readonly SMALL_HEIGHT: number = 40
  /** Small input border radius */
  static readonly SMALL_RADIUS: number = 20
}

// ─── Header / Top Bar Tokens ──────────────────────────────────
// Page header bar dimensions
// ═══════════════════════════════════════════════════════════════

export class AppHeader {
  /** Header content width */
  static readonly WIDTH: string = '92%'
  /** Header top padding */
  static readonly TOP_PADDING: number = 14
  /** Header title font size */
  static readonly TITLE_SIZE: number = 20
  /** Header bottom padding */
  static readonly BOTTOM_PADDING: number = 8
  /** Back button size */
  static readonly BACK_SIZE: number = 32
}


