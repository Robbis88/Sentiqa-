import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import "@/components/ui/ui.css";
import { RegistrerSW } from "./registrer-sw";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Sentiqa",
  description: "Fornemmer. Forstår. Forutser.",
  appleWebApp: { capable: true, statusBarStyle: "black-translucent", title: "Sentiqa" },
};

export const viewport: Viewport = {
  themeColor: "#0a0f1f",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="nb"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        <RegistrerSW />
        {children}
      </body>
    </html>
  );
}
