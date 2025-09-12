package com.acme.claims.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
@RequiredArgsConstructor
public class JwtAuthFilter extends OncePerRequestFilter {
//	@Autowired
//	private JwtService jwtService;
//	@Autowired
//	private UserDetailsService uds;
//
	@Override
	protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
			throws ServletException, IOException {
//		var h = req.getHeader("Authorization");
//		if (h != null && h.startsWith("Bearer ")) {
//			try {
//				var body = jwtService.parse(h.substring(7)).getBody();
//				var user = uds.loadUserByUsername(body.getSubject());
//				var auth = new UsernamePasswordAuthenticationToken(user, null, user.getAuthorities());
//				auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(req));
//				SecurityContextHolder.getContext().setAuthentication(auth);
//			} catch (Exception ignored) {
//			}
//		}
//		chain.doFilter(req, res);
	}
}
